$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host 'Odoo MCP demo delivery information' -ForegroundColor Cyan
Write-Host 'WARNING: The values below are demo credentials. Do not reuse them.' -ForegroundColor Yellow

$values = azd env get-values
$keys = @(
    'AZURE_RESOURCE_GROUP',
    'AZURE_CONTAINER_GROUP_NAME',
    'AZURE_PORTAL_URL',
    'ODOO_URL',
    'MCP_URL',
    'ODOO_DATABASE',
    'ODOO_ADMIN_LOGIN',
    'ODOO_ADMIN_PASSWORD',
    'ODOO_MASTER_PASSWORD',
    'POSTGRES_PASSWORD',
    'MCP_API_KEY'
)

foreach ($key in $keys) {
    $line = $values | Where-Object { $_ -match "^$key=" } | Select-Object -First 1
    if ($line) {
        Write-Host $line
    }
}

Write-Host ''
Write-Host 'The bootstrap and initial HTTPS certificate issuance can take several minutes. Inspect the Odoo and Caddy container logs in the Azure portal if an endpoint is not ready yet.'
