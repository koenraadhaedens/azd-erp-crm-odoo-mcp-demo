#!/usr/bin/env sh
set -eu

get_azd_value() {
	value="$(azd env get-value "$1" 2>/dev/null || true)"
	if [ -n "$value" ]; then
		printf '%s' "$value"
	else
		printf '<not available>'
	fi
}

printf '\nOdoo MCP demo delivery information\n'
printf 'WARNING: The values below are demo credentials. Do not reuse them.\n'

printf '\nEndpoints\n'
printf '  Odoo URL:        %s\n' "$(get_azd_value ODOO_URL)"
printf '  MCP URL:         %s\n' "$(get_azd_value MCP_URL)"
printf '  Azure portal:    %s\n' "$(get_azd_value AZURE_PORTAL_URL)"

printf '\nOdoo credentials\n'
printf '  Database:        %s\n' "$(get_azd_value ODOO_DATABASE)"
printf '  Administrator:   %s\n' "$(get_azd_value ODOO_ADMIN_LOGIN)"
printf '  Password:        %s\n' "$(get_azd_value ODOO_ADMIN_PASSWORD)"
printf '  Master password: %s\n' "$(get_azd_value ODOO_MASTER_PASSWORD)"

printf '\nPostgreSQL credentials\n'
printf '  User:            odoo\n'
printf '  Password:        %s\n' "$(get_azd_value POSTGRES_PASSWORD)"

printf '\nMCP authentication\n'
printf '  API key:         %s\n' "$(get_azd_value MCP_API_KEY)"

printf '\nAzure resources\n'
printf '  Resource group:  %s\n' "$(get_azd_value AZURE_RESOURCE_GROUP)"
printf '  Container group: %s\n' "$(get_azd_value AZURE_CONTAINER_GROUP_NAME)"

printf '\nThe bootstrap and initial HTTPS certificate issuance can take several minutes. Inspect the Odoo and Caddy container logs in the Azure portal if an endpoint is not ready yet.\n'
