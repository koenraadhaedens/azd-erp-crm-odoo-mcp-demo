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

show_bootstrap_logs() {
	printf '\nRecent Odoo bootstrap logs:\n' >&2
	az container logs \
		--resource-group "$RESOURCE_GROUP" \
		--name "$CONTAINER_GROUP" \
		--container-name odoo-bootstrap \
		--tail 100 \
		--only-show-errors >&2 || true
}

wait_odoo_bootstrap() {
	if ! command -v az >/dev/null 2>&1; then
		printf 'Azure CLI is required to monitor Odoo initialization.\n' >&2
		exit 1
	fi
	if ! az account show --output none --only-show-errors 2>/dev/null; then
		printf 'Azure CLI is not authenticated. Run az login and retry.\n' >&2
		exit 1
	fi

	RESOURCE_GROUP="$(get_azd_value AZURE_RESOURCE_GROUP)"
	CONTAINER_GROUP="$(get_azd_value AZURE_CONTAINER_GROUP_NAME)"
	if [ "$RESOURCE_GROUP" = '<not available>' ] || [ "$CONTAINER_GROUP" = '<not available>' ]; then
		printf 'The Azure resource group or container group is missing from the azd environment.\n' >&2
		exit 1
	fi

	elapsed=0
	frame=0
	while [ "$elapsed" -lt 1200 ]; do
		state="$(az container show \
			--resource-group "$RESOURCE_GROUP" \
			--name "$CONTAINER_GROUP" \
			--query "containers[?name=='odoo-bootstrap'].instanceView.currentState.state | [0]" \
			--output tsv \
			--only-show-errors 2>/dev/null || true)"

		if [ "$state" = 'Terminated' ]; then
			exit_code="$(az container show \
				--resource-group "$RESOURCE_GROUP" \
				--name "$CONTAINER_GROUP" \
				--query "containers[?name=='odoo-bootstrap'].instanceView.currentState.exitCode | [0]" \
				--output tsv \
				--only-show-errors 2>/dev/null || true)"
			printf '\r%-100s\r' ''
			if [ "$exit_code" = '0' ]; then
				printf 'OK Odoo applications and realistic demo data are ready.\n'
				return
			fi

			printf 'FAILED Odoo bootstrap exited with code %s.\n' "${exit_code:-unknown}" >&2
			show_bootstrap_logs
			printf 'Odoo initialization failed; delivery credentials were not displayed.\n' >&2
			exit 1
		fi

		case $((frame % 4)) in
			0) spinner='|' ;;
			1) spinner='/' ;;
			2) spinner='-' ;;
			*) spinner='\' ;;
		esac
		printf '\r[%s] Installing Odoo applications and realistic demo data... %ss' "$spinner" "$elapsed"
		frame=$((frame + 1))
		sleep 5
		elapsed=$((elapsed + 5))
	done

	printf '\r%-100s\r' ''
	printf 'TIMEOUT Odoo bootstrap did not finish within 20 minutes.\n' >&2
	show_bootstrap_logs
	printf 'Odoo initialization timed out; delivery credentials were not displayed.\n' >&2
	exit 1
}

printf '\n'
wait_odoo_bootstrap

printf '\nOdoo MCP demo delivery information\n'
printf 'WARNING: The values below are demo credentials. Do not reuse them.\n'

printf '\nEndpoints\n'
printf '  Odoo URL:        %s\n' "$(get_azd_value ODOO_URL)"
printf '  MCP URL:         %s\n' "$(get_azd_value MCP_URL)"
printf '  Azure portal:    %s\n' "$(get_azd_value AZURE_PORTAL_URL)"

printf '\nOdoo credentials\n'
printf '  Database:                  %s\n' "$(get_azd_value ODOO_DATABASE)"
printf '  Web login:                 %s\n' "$(get_azd_value ODOO_ADMIN_LOGIN)"
printf '  Web login password:        %s\n' "$(get_azd_value ODOO_ADMIN_PASSWORD)"
printf '  Database manager password: %s\n' "$(get_azd_value ODOO_MASTER_PASSWORD)"

printf '\nPostgreSQL credentials\n'
printf '  User:            odoo\n'
printf '  Password:        %s\n' "$(get_azd_value POSTGRES_PASSWORD)"

printf '\nMCP authentication\n'
printf '  API key:         %s\n' "$(get_azd_value MCP_API_KEY)"

printf '\nAzure resources\n'
printf '  Resource group:  %s\n' "$(get_azd_value AZURE_RESOURCE_GROUP)"
printf '  Container group: %s\n' "$(get_azd_value AZURE_CONTAINER_GROUP_NAME)"

printf '\nOdoo initialization is complete. Initial HTTPS certificate issuance may still take a short time.\n'
