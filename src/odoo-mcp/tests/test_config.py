from __future__ import annotations

import pytest

from odoo_mcp.config import ConfigurationError, Settings

REQUIRED = {
    "ODOO_URL": "http://127.0.0.1:8069",
    "ODOO_DATABASE": "odoo_demo",
    "ODOO_USERNAME": "admin",
    "ODOO_PASSWORD": "admin-secret",
    "MCP_API_KEY": "mcp-secret",
}


def test_settings_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    for name, value in REQUIRED.items():
        monkeypatch.setenv(name, value)
    monkeypatch.setenv("MCP_ALLOWED_HOSTS", "demo.example, demo.example:*")

    value = Settings.from_env()

    assert value.odoo_database == "odoo_demo"
    assert value.allowed_hosts == ("demo.example", "demo.example:*")
    assert value.port == 8000


def test_invalid_odoo_url_is_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    for name, value in REQUIRED.items():
        monkeypatch.setenv(name, value)
    monkeypatch.setenv("ODOO_URL", "file:///etc/passwd")

    with pytest.raises(ConfigurationError, match="absolute HTTP"):
        Settings.from_env()
