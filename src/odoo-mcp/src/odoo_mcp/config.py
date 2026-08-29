from __future__ import annotations

import os
from dataclasses import dataclass
from urllib.parse import urlparse


class ConfigurationError(ValueError):
    """Raised when required server configuration is invalid."""


def _required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ConfigurationError(f"{name} is required")
    return value


def _positive_int(name: str, default: int, maximum: int) -> int:
    raw = os.getenv(name, str(default))
    try:
        value = int(raw)
    except ValueError as exc:
        raise ConfigurationError(f"{name} must be an integer") from exc
    if not 1 <= value <= maximum:
        raise ConfigurationError(f"{name} must be between 1 and {maximum}")
    return value


@dataclass(frozen=True, slots=True)
class Settings:
    odoo_url: str
    odoo_database: str
    odoo_username: str
    odoo_password: str
    api_key: str
    host: str
    port: int
    request_timeout_seconds: int
    allowed_hosts: tuple[str, ...]

    @classmethod
    def from_env(cls) -> Settings:
        odoo_url = _required("ODOO_URL").rstrip("/")
        parsed = urlparse(odoo_url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ConfigurationError("ODOO_URL must be an absolute HTTP or HTTPS URL")

        port = _positive_int("MCP_PORT", 8000, 65535)
        allowed_hosts = tuple(
            host.strip()
            for host in os.getenv(
                "MCP_ALLOWED_HOSTS", "localhost,localhost:*,127.0.0.1,127.0.0.1:*"
            ).split(",")
            if host.strip()
        )
        if not allowed_hosts:
            raise ConfigurationError("MCP_ALLOWED_HOSTS must contain at least one host")

        return cls(
            odoo_url=odoo_url,
            odoo_database=os.getenv("ODOO_DATABASE", os.getenv("ODOO_DB", "")).strip()
            or _required("ODOO_DB"),
            odoo_username=_required("ODOO_USERNAME"),
            odoo_password=_required("ODOO_PASSWORD"),
            api_key=_required("MCP_API_KEY"),
            host=os.getenv("MCP_HOST", "0.0.0.0"),
            port=port,
            request_timeout_seconds=_positive_int("ODOO_TIMEOUT_SECONDS", 20, 120),
            allowed_hosts=allowed_hosts,
        )
