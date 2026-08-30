# Disposable Odoo ERP/CRM MCP demo on Azure Container Instances

This repository deploys a reproducible Odoo demonstration sandbox into one Azure Container Instances (ACI) container group. PostgreSQL, an Odoo bootstrap process, Odoo, the MCP server, and Caddy share the group's loopback network while remaining separate containers.

## What gets deployed

- PostgreSQL 16 with ephemeral `emptyDir` storage.
- An Odoo 18 bootstrap container that creates a fresh database, loads demo data, installs CRM/ERP modules, and changes the Odoo administrator password.
- A deterministic Contoso scenario with connected customers, vendors, products, inventory, opportunities, quotations, sales and purchase orders, projects, employees, maintenance, fleet, manufacturing, and accounting records.
- Odoo 18, listening internally on TCP 8069.
- The Odoo MCP server, listening internally on TCP 8000 by default and configured for Odoo JSON-RPC over `http://127.0.0.1:8069`.
- Caddy as the only public ingress on TCP 80 and 443, with automatic HTTPS for the generated ACI FQDN.

Every reprovision replaces the sandbox and its generated credentials. This is intentional and makes the project suitable for workshops and isolated demos; it is not a production architecture.

## Included container sources

The repository includes build contexts for all four images:

| Repository/tag | Source |
| --- | --- |
| `odoo:<tag>` | `src/odoo`, based on Odoo 18. |
| `postgres:<tag>` | `src/postgres`, based on PostgreSQL 16 Bookworm. |
| `odoo-mcp:<tag>` | `src/odoo-mcp`, the authenticated Python MCP server. |
| `caddy-odoo:<tag>` | `src/caddy`, the project-specific HTTPS reverse proxy and routing configuration. |

By default, `azd up` builds all four images remotely in `acrdefcontainer.azurecr.io` from this repository before provisioning ACI:

```text
azd up
```

Each build also updates the stable tag used by the Bicep default: `odoo:18.0`, `postgres:16`, `odoo-mcp:latest`, or `caddy-odoo:latest`. Immutable revision tags remain the values used by the normal `azd up` workflow.
Remote ACR builds do not require local Docker. They require Azure CLI authentication and permission to queue builds in `acrdefcontainer`. Anonymous pull access is enabled on this registry, so ACI does not require registry credentials. The build is tagged with the current Git commit and reused until `IMAGE_TAG` changes. Set a new tag explicitly when rebuilding unchanged committed source:

```text
azd env set IMAGE_TAG workshop-v2
azd up
```

To use images that already exist in the registry instead, set `BUILD_IMAGES=false` and configure `ODOO_IMAGE`, `POSTGRES_IMAGE`, `MCP_IMAGE`, and `CADDY_IMAGE` in the selected `azd` environment.

## Deploy

Prerequisites:

1. Azure Developer CLI (`azd`).
2. Access to an Azure subscription with permission to create a resource group and ACI container group.
3. Azure CLI (`az`) only when `BUILD_IMAGES=true`.

Run:

```text
azd auth login
azd up
```

Select the subscription and region. A first provisioning layer generates disposable application credentials as deployment outputs. `azd` propagates them to the dependent application layer as secure Bicep parameters and saves them in the local environment so the post-provision delivery summary can print them. The summary also runs after `azd deploy`.

The delivery hook displays an animated initialization status and waits up to 20 minutes for the `odoo-bootstrap` container to finish successfully. Endpoints and credentials are printed only after the applications and realistic demo data are ready. If initialization fails or times out, the hook prints recent bootstrap logs and fails without displaying credentials.

The credential outputs are intentionally not marked secure because Azure Developer CLI does not persist secure outputs. Consequently, these demo credentials are visible in deployment outputs and local `azd` state. This tradeoff is suitable only for this disposable workshop sandbox; production deployments must use Key Vault or managed identity and must not print credentials.

To reset an existing environment with a new empty database and new credentials:

```text
azd deploy
```

Because ACI is an infrastructure resource rather than an `azd` application host, the `predeploy` hook runs `azd provision`; the subsequent deploy phase has no source artifact to upload. `azd up` can therefore perform one additional idempotent provision pass.

To review changes before deploying, use `azd provision --preview`.

## Initialization flow

1. PostgreSQL starts and initializes an empty data directory.
2. `odoo-bootstrap` waits for TCP 5432, creates `odoo_demo`, and installs the `realistic_demo` add-on and its CRM, sales, purchase, inventory, accounting, project, HR, maintenance, fleet, manufacturing, website/e-commerce, and point-of-sale dependencies with Odoo demo data enabled.
3. The bootstrap runs a deterministic seed script that creates an internally connected Contoso business scenario and then rotates the admin password.
4. The bootstrap writes a readiness marker to a shared ephemeral volume.
5. The Odoo web container sees the marker and starts against the initialized database.
6. The MCP server connects to Odoo through the container group's loopback network.
7. Caddy obtains a public certificate and routes HTTPS traffic to the internal application listeners.

The seed uses `DEMO-` references, SKUs, and names so its records are easy to find. Workflow records are created through Odoo's ORM and normal confirmation/posting actions. Optional accounting or operational records are skipped with a bootstrap log message if the corresponding company configuration is unavailable; the core CRM, sales, purchase, inventory, project, and HR scenario still completes.

Only Caddy ports 80 and 443 are public. PostgreSQL, Odoo, and MCP have no public ACI port mappings.

The Odoo image starts through a root wrapper only long enough to set ownership on ACI's root-owned readiness volume, then immediately drops to the stock non-root `odoo` account before running bootstrap or the web server.

## HTTPS endpoints

The deployment uses the generated Azure Container Instances hostname directly; no custom domain is required. It returns these endpoints on one `*.azurecontainer.io` FQDN:

- `ODOO_URL`: `https://<fqdn>`
- `MCP_URL`: `https://<fqdn>/mcp`

Caddy routes `/mcp` and `/mcp/*` to MCP without stripping the path. All other paths go to Odoo. Incoming authorization headers are preserved, and Caddy supplies the forwarding headers consumed by Odoo's proxy mode. Port 80 remains open for ACME HTTP validation and redirects normal HTTP requests to HTTPS.

Initial certificate issuance happens asynchronously and can take a short time after ACI starts. Caddy validates the generated ACI hostname over ports 80/443 and obtains a publicly trusted certificate for that exact hostname. Caddy stores certificates under `/data` in a writable group volume, which survives individual container restarts but is deleted with this disposable container group. Repeatedly replacing the group can trigger public certificate-authority rate limits.

## MCP server

The HTTPS Streamable HTTP endpoint is returned as `MCP_URL` and ends in `/mcp`. Clients must send the generated key as an HTTP bearer token:

```text
Authorization: Bearer <MCP_API_KEY>
```

The server provides bounded tools for health, contact search/creation, CRM lead search/creation, product search, and sales-order listing. It intentionally does not expose arbitrary Odoo models, methods, domains, or fields. See `src/odoo-mcp/README.md` for its environment contract and tool list.

## Important security note

The post-delivery scripts intentionally display generated credentials because this repository is a disposable demo. Avoid CI log retention, screen sharing, or reuse of these values. For production, remove credential printing, use managed identity/Key Vault, use a managed TLS ingress, and use persistent managed database/storage services.
