#!/usr/bin/env sh
set -eu

printf '\nOdoo MCP demo delivery information\n'
printf 'WARNING: The values below are demo credentials. Do not reuse them.\n'

azd env get-values | grep -E '^(AZURE_RESOURCE_GROUP|AZURE_CONTAINER_GROUP_NAME|AZURE_PORTAL_URL|ODOO_URL|MCP_URL|ODOO_DATABASE|ODOO_ADMIN_LOGIN|ODOO_ADMIN_PASSWORD|ODOO_MASTER_PASSWORD|POSTGRES_PASSWORD|MCP_API_KEY)=' || true

printf '\nThe bootstrap and initial HTTPS certificate issuance can take several minutes. Inspect the Odoo and Caddy container logs in the Azure portal if an endpoint is not ready yet.\n'
