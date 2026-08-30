#!/usr/bin/env sh
set -eu

REGISTRY="${1:-acrdefcontainer}"
TAG="${2:-}"
case "$TAG" in
  ""|*[!a-zA-Z0-9._-]* )
    printf 'Usage: %s [registry] <tag>\n' "$0" >&2
    exit 2
    ;;
esac

if ! command -v az >/dev/null 2>&1; then
  printf 'Azure CLI is required when BUILD_IMAGES=true. Install it and run az login.\n' >&2
  exit 1
fi

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

build_image() {
  image="$1"
  alias="$2"
  dockerfile="$3"
  context="$4"
  printf 'Building %s in %s...\n' "$image" "$REGISTRY"
  az acr build \
    --registry "$REGISTRY" \
    --image "$image" \
    --image "$alias" \
    --file "$dockerfile" \
    "$context" \
    --output none \
    --only-show-errors
}

build_image "odoo:$TAG" "odoo:demo-latest" "src/odoo/Dockerfile" "src/odoo"
build_image "postgres:$TAG" "postgres:16" "src/postgres/Dockerfile" "src/postgres"
build_image "odoo-mcp:$TAG" "odoo-mcp:latest" "src/odoo-mcp/Dockerfile" "src/odoo-mcp"
build_image "caddy-odoo:$TAG" "caddy-odoo:latest" "src/caddy/Dockerfile" "src/caddy"
