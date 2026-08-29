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
  dockerfile="$2"
  context="$3"
  printf 'Building %s in %s...\n' "$image" "$REGISTRY"
  az acr build \
    --registry "$REGISTRY" \
    --image "$image" \
    --file "$dockerfile" \
    "$context" \
    --output none \
    --only-show-errors
}

build_image "odoo:$TAG" "src/odoo/Dockerfile" "src/odoo"
build_image "postgres:$TAG" "src/postgres/Dockerfile" "src/postgres"
build_image "odoo-mcp:$TAG" "src/odoo-mcp/Dockerfile" "src/odoo-mcp"
build_image "caddy-odoo:$TAG" "src/caddy/Dockerfile" "src/caddy"
