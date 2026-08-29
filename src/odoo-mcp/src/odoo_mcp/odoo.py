from __future__ import annotations

import asyncio
import logging
import uuid
from typing import Any

import httpx

from .config import Settings

logger = logging.getLogger(__name__)


class OdooError(RuntimeError):
    """A safe error raised when Odoo authentication or JSON-RPC fails."""


class OdooClient:
    def __init__(self, settings: Settings, http: httpx.AsyncClient | None = None) -> None:
        self._settings = settings
        self._http = http or httpx.AsyncClient(
            base_url=settings.odoo_url,
            timeout=httpx.Timeout(settings.request_timeout_seconds),
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )
        self._owns_http = http is None
        self._uid: int | None = None
        self._auth_lock = asyncio.Lock()

    async def close(self) -> None:
        if self._owns_http:
            await self._http.aclose()

    async def _json_rpc(self, service: str, method: str, *args: Any) -> Any:
        payload = {
            "jsonrpc": "2.0",
            "method": "call",
            "params": {"service": service, "method": method, "args": list(args)},
            "id": uuid.uuid4().hex,
        }
        delay = 0.5
        for attempt in range(4):
            try:
                response = await self._http.post("/jsonrpc", json=payload)
                response.raise_for_status()
                body = response.json()
                if "error" in body:
                    error = body["error"]
                    message = error.get("message", "Odoo JSON-RPC error")
                    data = error.get("data", {})
                    detail = data.get("message") if isinstance(data, dict) else None
                    raise OdooError(str(detail or message))
                if "result" not in body:
                    raise OdooError("Odoo returned an invalid JSON-RPC response")
                return body["result"]
            except OdooError:
                raise
            except (httpx.HTTPError, ValueError) as exc:
                if attempt == 3:
                    logger.warning("Odoo JSON-RPC failed after retries: %s", type(exc).__name__)
                    raise OdooError("Odoo is temporarily unavailable") from exc
                await asyncio.sleep(delay)
                delay *= 2
        raise OdooError("Odoo is temporarily unavailable")

    async def authenticate(self, *, force: bool = False) -> int:
        if self._uid is not None and not force:
            return self._uid
        async with self._auth_lock:
            if self._uid is not None and not force:
                return self._uid
            uid = await self._json_rpc(
                "common",
                "login",
                self._settings.odoo_database,
                self._settings.odoo_username,
                self._settings.odoo_password,
            )
            if not isinstance(uid, int) or uid <= 0:
                raise OdooError("Odoo authentication failed")
            self._uid = uid
            return uid

    async def execute(
        self, model: str, method: str, args: list[Any], kwargs: dict[str, Any]
    ) -> Any:
        uid = await self.authenticate()
        try:
            return await self._json_rpc(
                "object",
                "execute_kw",
                self._settings.odoo_database,
                uid,
                self._settings.odoo_password,
                model,
                method,
                args,
                kwargs,
            )
        except OdooError as exc:
            if "access denied" not in str(exc).lower() and "session" not in str(exc).lower():
                raise
            uid = await self.authenticate(force=True)
            return await self._json_rpc(
                "object",
                "execute_kw",
                self._settings.odoo_database,
                uid,
                self._settings.odoo_password,
                model,
                method,
                args,
                kwargs,
            )

    async def search_read(
        self,
        model: str,
        domain: list[Any],
        fields: list[str],
        *,
        limit: int,
        order: str = "id desc",
    ) -> list[dict[str, Any]]:
        result = await self.execute(
            model,
            "search_read",
            [domain],
            {"fields": fields, "limit": min(max(limit, 1), 100), "order": order},
        )
        if not isinstance(result, list):
            raise OdooError("Odoo returned an unexpected record list")
        return result

    async def create(self, model: str, values: dict[str, Any]) -> int:
        result = await self.execute(model, "create", [values], {})
        if not isinstance(result, int):
            raise OdooError("Odoo returned an unexpected create result")
        return result

    async def health(self) -> dict[str, Any]:
        version = await self._json_rpc("common", "version")
        uid = await self.authenticate()
        return {
            "status": "ready",
            "database": self._settings.odoo_database,
            "authenticated": uid > 0,
            "odoo_version": version.get("server_version") if isinstance(version, dict) else None,
        }
