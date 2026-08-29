#!/usr/bin/env sh
set -eu

get_azd_value() {
  azd env get-value "$1" 2>/dev/null || true
}

ACR_NAME_VALUE="$(get_azd_value ACR_NAME)"
ACR_NAME_VALUE="${ACR_NAME_VALUE:-acrdefcontainer}"
azd env set ACR_NAME "$ACR_NAME_VALUE"
ACR_SERVER_VALUE="$ACR_NAME_VALUE.azurecr.io"

BUILD_IMAGES_VALUE="$(get_azd_value BUILD_IMAGES)"
BUILD_IMAGES_VALUE="${BUILD_IMAGES_VALUE:-true}"
azd env set BUILD_IMAGES "$BUILD_IMAGES_VALUE"

if [ "$BUILD_IMAGES_VALUE" = "true" ]; then
  IMAGE_TAG_VALUE="$(get_azd_value IMAGE_TAG)"
  if [ -z "$IMAGE_TAG_VALUE" ]; then
    IMAGE_TAG_VALUE="$(git rev-parse --short=12 HEAD 2>/dev/null || date -u +%Y%m%d%H%M%S)"
    azd env set IMAGE_TAG "$IMAGE_TAG_VALUE"
  fi
  IMAGE_BUILD_KEY="${IMAGE_TAG_VALUE}-caddy-odoo-v1"
  LAST_BUILT_TAG_VALUE="$(get_azd_value LAST_BUILT_IMAGE_TAG)"
  if [ "$LAST_BUILT_TAG_VALUE" != "$IMAGE_BUILD_KEY" ]; then
    sh "$(dirname "$0")/build-images.sh" "$ACR_NAME_VALUE" "$IMAGE_TAG_VALUE"
    azd env set LAST_BUILT_IMAGE_TAG "$IMAGE_BUILD_KEY"
  fi
  azd env set ODOO_IMAGE "$ACR_SERVER_VALUE/odoo:$IMAGE_TAG_VALUE"
  azd env set POSTGRES_IMAGE "$ACR_SERVER_VALUE/postgres:$IMAGE_TAG_VALUE"
  azd env set MCP_IMAGE "$ACR_SERVER_VALUE/odoo-mcp:$IMAGE_TAG_VALUE"
  azd env set CADDY_IMAGE "$ACR_SERVER_VALUE/caddy-odoo:$IMAGE_TAG_VALUE"
else
  [ -n "$(get_azd_value ODOO_IMAGE)" ] || azd env set ODOO_IMAGE "$ACR_SERVER_VALUE/odoo:18.0"
  [ -n "$(get_azd_value POSTGRES_IMAGE)" ] || azd env set POSTGRES_IMAGE "$ACR_SERVER_VALUE/postgres:16"
  [ -n "$(get_azd_value MCP_IMAGE)" ] || azd env set MCP_IMAGE "$ACR_SERVER_VALUE/odoo-mcp:latest"
  [ -n "$(get_azd_value CADDY_IMAGE)" ] || azd env set CADDY_IMAGE "$ACR_SERVER_VALUE/caddy-odoo:latest"
fi
