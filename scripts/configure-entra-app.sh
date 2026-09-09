#!/usr/bin/env sh
set -eu

get_azd_value() {
  azd env get-value "$1" 2>/dev/null || true
}

TENANT_ID="$(az account show --query tenantId --output tsv --only-show-errors)"
azd env set ENTRA_TENANT_ID "$TENANT_ID"

CLIENT_ID="$(get_azd_value ENTRA_APP_CLIENT_ID)"
if [ -n "$CLIENT_ID" ]; then
  printf 'Using existing Entra application %s.\n' "$CLIENT_ID"
  exit 0
fi

ENVIRONMENT_NAME="$(get_azd_value AZURE_ENV_NAME)"
DISPLAY_NAME="Odoo MCP APIM demo - $ENVIRONMENT_NAME"
APPLICATION="$(az ad app list \
  --display-name "$DISPLAY_NAME" \
  --query '[0].{id:id,appId:appId}' \
  --output json \
  --only-show-errors)"

if [ "$APPLICATION" = 'null' ] || [ -z "$APPLICATION" ]; then
  printf "Creating Entra application '%s'...\n" "$DISPLAY_NAME"
  APPLICATION="$(az ad app create \
    --display-name "$DISPLAY_NAME" \
    --sign-in-audience AzureADMyOrg \
    --is-fallback-public-client true \
    --public-client-redirect-uris http://localhost \
    --query '{id:id,appId:appId}' \
    --output json \
    --only-show-errors)"
fi

OBJECT_ID="$(printf '%s' "$APPLICATION" | jq -r '.id')"
CLIENT_ID="$(printf '%s' "$APPLICATION" | jq -r '.appId')"
SCOPE_ID="$(az rest \
  --method GET \
  --uri "https://graph.microsoft.com/v1.0/applications/$OBJECT_ID?\$select=api" \
  --query "api.oauth2PermissionScopes[?value=='mcp.access'].id | [0]" \
  --output tsv \
  --only-show-errors)"
SCOPE_ID="${SCOPE_ID:-$(cat /proc/sys/kernel/random/uuid)}"

BODY_PATH="$(mktemp)"
trap 'rm -f "$BODY_PATH"' EXIT
jq -n \
  --arg clientId "$CLIENT_ID" \
  --arg scopeId "$SCOPE_ID" \
  '{
    identifierUris: ["api://" + $clientId],
    isFallbackPublicClient: true,
    publicClient: { redirectUris: ["http://localhost"] },
    api: {
      requestedAccessTokenVersion: 2,
      oauth2PermissionScopes: [{
        adminConsentDescription: "Allow this client to access the Odoo MCP demo through API Management.",
        adminConsentDisplayName: "Access the Odoo MCP demo",
        id: $scopeId,
        isEnabled: true,
        type: "User",
        userConsentDescription: "Allow this application to access the Odoo MCP demo on your behalf.",
        userConsentDisplayName: "Access the Odoo MCP demo",
        value: "mcp.access"
      }]
    }
  }' > "$BODY_PATH"

az rest \
  --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications/$OBJECT_ID" \
  --headers 'Content-Type=application/json' \
  --body "@$BODY_PATH" \
  --output none \
  --only-show-errors

azd env set ENTRA_APP_CLIENT_ID "$CLIENT_ID"
printf 'Configured Entra application %s.\n' "$CLIENT_ID"