from __future__ import annotations

import contextlib
import hmac
import logging
from collections.abc import AsyncIterator
from typing import Any

import uvicorn
from mcp.server import MCPServer
from mcp.server.transport_security import TransportSecuritySettings
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.routing import Mount, Route
from starlette.types import ASGIApp, Receive, Scope, Send

from .config import Settings
from .odoo import OdooClient

logger = logging.getLogger(__name__)
MAX_LIMIT = 100


def _text(value: str, name: str, maximum: int = 200) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{name} is required")
    if len(normalized) > maximum:
        raise ValueError(f"{name} must not exceed {maximum} characters")
    return normalized


def _limit(value: int) -> int:
    if not 1 <= value <= MAX_LIMIT:
        raise ValueError(f"limit must be between 1 and {MAX_LIMIT}")
    return value


class BearerAuthMiddleware:
    """Require the configured static demo bearer key without logging it."""

    def __init__(self, app: ASGIApp, api_key: str) -> None:
        self.app = app
        self._expected = f"Bearer {api_key}"

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope.get("path") == "/health":
            await self.app(scope, receive, send)
            return

        headers = {key.lower(): value for key, value in scope.get("headers", [])}
        supplied = headers.get(b"authorization", b"").decode("latin-1")
        if not hmac.compare_digest(supplied, self._expected):
            response = JSONResponse(
                {"error": "unauthorized"},
                status_code=401,
                headers={"WWW-Authenticate": "Bearer"},
            )
            await response(scope, receive, send)
            return
        await self.app(scope, receive, send)


def create_mcp_server(client: OdooClient) -> MCPServer:
    server = MCPServer(
        "odoo-erp-crm-demo",
        title="Odoo ERP/CRM Demo",
        description="Bounded business tools for the disposable Odoo demo environment.",
        instructions=(
            "Use search tools before creating records. Never invent record identifiers. "
            "Creation tools change the disposable demo database."
        ),
        version="0.1.0",
    )

    @server.tool()
    async def odoo_health() -> dict[str, Any]:
        """Check Odoo availability, version, database, and authentication."""
        return await client.health()

    @server.tool()
    async def search_contacts(query: str = "", limit: int = 20) -> list[dict[str, Any]]:
        """Find companies and people by name, email, or phone. Returns at most 100 records."""
        safe_limit = _limit(limit)
        query = query.strip()[:200]
        domain: list[Any] = []
        if query:
            domain = [
                "|",
                "|",
                ["name", "ilike", query],
                ["email", "ilike", query],
                ["phone", "ilike", query],
            ]
        return await client.search_read(
            "res.partner",
            domain,
            ["id", "name", "email", "phone", "company_type", "city", "country_id"],
            limit=safe_limit,
            order="name asc",
        )

    @server.tool()
    async def create_contact(
        name: str,
        email: str = "",
        phone: str = "",
        company_name: str = "",
    ) -> dict[str, Any]:
        """Create one contact. Use only after confirming that no matching contact exists."""
        values: dict[str, Any] = {"name": _text(name, "name")}
        if email.strip():
            values["email"] = _text(email, "email", 254)
        if phone.strip():
            values["phone"] = _text(phone, "phone", 50)
        if company_name.strip():
            matches = await client.search_read(
                "res.partner",
                [
                    ["name", "=ilike", _text(company_name, "company_name")],
                    ["is_company", "=", True],
                ],
                ["id", "name"],
                limit=2,
            )
            if len(matches) != 1:
                raise ValueError("company_name must resolve to exactly one company")
            values["parent_id"] = matches[0]["id"]
        record_id = await client.create("res.partner", values)
        return {"id": record_id, "name": values["name"], "created": True}

    @server.tool()
    async def list_crm_leads(query: str = "", limit: int = 20) -> list[dict[str, Any]]:
        """List CRM leads and opportunities, optionally filtered by title or customer."""
        safe_limit = _limit(limit)
        query = query.strip()[:200]
        domain: list[Any] = []
        if query:
            domain = ["|", ["name", "ilike", query], ["partner_name", "ilike", query]]
        return await client.search_read(
            "crm.lead",
            domain,
            [
                "id",
                "name",
                "type",
                "partner_id",
                "partner_name",
                "email_from",
                "phone",
                "stage_id",
                "expected_revenue",
                "probability",
                "user_id",
            ],
            limit=safe_limit,
        )

    @server.tool()
    async def create_crm_lead(
        title: str,
        customer_name: str,
        email: str = "",
        phone: str = "",
        expected_revenue: float = 0,
    ) -> dict[str, Any]:
        """Create one CRM lead with validated, bounded customer details."""
        if not 0 <= expected_revenue <= 1_000_000_000:
            raise ValueError("expected_revenue must be between 0 and 1000000000")
        values: dict[str, Any] = {
            "name": _text(title, "title"),
            "partner_name": _text(customer_name, "customer_name"),
            "type": "lead",
            "expected_revenue": expected_revenue,
        }
        if email.strip():
            values["email_from"] = _text(email, "email", 254)
        if phone.strip():
            values["phone"] = _text(phone, "phone", 50)
        record_id = await client.create("crm.lead", values)
        return {"id": record_id, "title": values["name"], "created": True}

    @server.tool()
    async def search_products(query: str = "", limit: int = 20) -> list[dict[str, Any]]:
        """Search saleable products by name, SKU, or barcode."""
        safe_limit = _limit(limit)
        query = query.strip()[:200]
        domain: list[Any] = [["sale_ok", "=", True]]
        if query:
            domain = [
                ["sale_ok", "=", True],
                "|",
                "|",
                ["name", "ilike", query],
                ["default_code", "ilike", query],
                ["barcode", "=", query],
            ]
        return await client.search_read(
            "product.product",
            domain,
            ["id", "name", "default_code", "barcode", "list_price", "qty_available", "uom_id"],
            limit=safe_limit,
            order="name asc",
        )

    @server.tool()
    async def list_sales_orders(query: str = "", limit: int = 20) -> list[dict[str, Any]]:
        """List quotations and sales orders by order number or customer name."""
        safe_limit = _limit(limit)
        query = query.strip()[:200]
        domain: list[Any] = []
        if query:
            domain = ["|", ["name", "ilike", query], ["partner_id.name", "ilike", query]]
        return await client.search_read(
            "sale.order",
            domain,
            [
                "id",
                "name",
                "partner_id",
                "date_order",
                "state",
                "amount_untaxed",
                "amount_total",
                "currency_id",
            ],
            limit=safe_limit,
        )

    return server


def create_app(settings: Settings, client: OdooClient | None = None) -> ASGIApp:
    odoo = client or OdooClient(settings)
    server = create_mcp_server(odoo)

    async def health(_request: Request) -> Response:
        return JSONResponse({"status": "ok", "service": "odoo-mcp"})

    transport_security = TransportSecuritySettings(
        allowed_hosts=list(settings.allowed_hosts),
        allowed_origins=[],
    )
    mcp_app = server.streamable_http_app(
        streamable_http_path="/",
        stateless_http=True,
        json_response=True,
        max_request_body_size=1_048_576,
        transport_security=transport_security,
    )

    @contextlib.asynccontextmanager
    async def lifespan(_app: Starlette) -> AsyncIterator[None]:
        async with server.session_manager.run():
            try:
                yield
            finally:
                await odoo.close()

    app = Starlette(
        routes=[
            Route("/health", health, methods=["GET"]),
            Mount("/mcp", app=mcp_app),
        ],
        lifespan=lifespan,
    )
    return BearerAuthMiddleware(app, settings.api_key)


settings = Settings.from_env()
app = create_app(settings)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    logger.info("Starting Odoo MCP server on %s:%s", settings.host, settings.port)
    uvicorn.run(app, host=settings.host, port=settings.port, log_level="info")
