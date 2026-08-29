# Odoo MCP server

The server exposes authenticated Streamable HTTP at `/mcp` and an unauthenticated liveness endpoint at `/health`. It deliberately provides bounded business operations instead of arbitrary Odoo model execution.

## Tools

- `odoo_health`
- `search_contacts` and `create_contact`
- `list_crm_leads` and `create_crm_lead`
- `search_products`
- `list_sales_orders`

## Required environment

- `ODOO_URL`
- `ODOO_DATABASE` or `ODOO_DB`
- `ODOO_USERNAME`
- `ODOO_PASSWORD`
- `MCP_API_KEY`
- `MCP_ALLOWED_HOSTS`: comma-separated exact hosts; include both a bare host and `host:*` when clients use an explicit port.

Optional settings are `MCP_HOST`, `MCP_PORT`, and `ODOO_TIMEOUT_SECONDS`.

Send `Authorization: Bearer <MCP_API_KEY>` with every `/mcp` request. The health endpoint does not require authentication so container health checks can use it.
