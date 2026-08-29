from __future__ import annotations

import json

import httpx
import pytest

from odoo_mcp.config import Settings
from odoo_mcp.odoo import OdooClient, OdooError


def settings() -> Settings:
    return Settings(
        odoo_url="http://odoo.test",
        odoo_database="odoo_demo",
        odoo_username="admin",
        odoo_password="secret",
        api_key="api-secret",
        host="127.0.0.1",
        port=8000,
        request_timeout_seconds=5,
        allowed_hosts=("testserver",),
    )


@pytest.mark.asyncio
async def test_search_read_authenticates_and_bounds_limit() -> None:
    requests: list[dict[str, object]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        requests.append(payload)
        service = payload["params"]["service"]
        result = 7 if service == "common" else [{"id": 1, "name": "Azure Interior"}]
        return httpx.Response(200, json={"jsonrpc": "2.0", "id": payload["id"], "result": result})

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://odoo.test")
    client = OdooClient(settings(), http=http)

    result = await client.search_read("res.partner", [], ["id", "name"], limit=500)

    assert result == [{"id": 1, "name": "Azure Interior"}]
    assert requests[0]["params"]["method"] == "login"  # type: ignore[index]
    execute_args = requests[1]["params"]["args"]  # type: ignore[index]
    assert execute_args[4] == "search_read"
    assert execute_args[6]["limit"] == 100
    await http.aclose()


@pytest.mark.asyncio
async def test_odoo_error_does_not_expose_password() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        return httpx.Response(
            200,
            json={
                "jsonrpc": "2.0",
                "id": payload["id"],
                "error": {"message": "Access denied", "data": {"message": "Invalid login"}},
            },
        )

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://odoo.test")
    client = OdooClient(settings(), http=http)

    with pytest.raises(OdooError, match="Invalid login") as exc_info:
        await client.authenticate()

    assert "secret" not in str(exc_info.value)
    await http.aclose()
