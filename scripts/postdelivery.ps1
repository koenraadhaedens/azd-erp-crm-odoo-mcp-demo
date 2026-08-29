$ErrorActionPreference = 'Stop'

function Get-AzdEnvironmentValue([string]$Name) {
    $value = azd env get-value $Name 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
        return $value.Trim()
    }
    return '<not available>'
}

Write-Host ''
Write-Host 'Odoo MCP demo delivery information' -ForegroundColor Cyan
Write-Host 'WARNING: The values below are demo credentials. Do not reuse them.' -ForegroundColor Yellow

Write-Host ''
Write-Host 'Endpoints' -ForegroundColor Green
Write-Host "  Odoo URL:        $(Get-AzdEnvironmentValue 'ODOO_URL')"
Write-Host "  MCP URL:         $(Get-AzdEnvironmentValue 'MCP_URL')"
Write-Host "  Azure portal:    $(Get-AzdEnvironmentValue 'AZURE_PORTAL_URL')"

Write-Host ''
Write-Host 'Odoo credentials' -ForegroundColor Green
Write-Host "  Database:        $(Get-AzdEnvironmentValue 'ODOO_DATABASE')"
Write-Host "  Administrator:   $(Get-AzdEnvironmentValue 'ODOO_ADMIN_LOGIN')"
Write-Host "  Password:        $(Get-AzdEnvironmentValue 'ODOO_ADMIN_PASSWORD')"
Write-Host "  Master password: $(Get-AzdEnvironmentValue 'ODOO_MASTER_PASSWORD')"

Write-Host ''
Write-Host 'PostgreSQL credentials' -ForegroundColor Green
Write-Host '  User:            odoo'
Write-Host "  Password:        $(Get-AzdEnvironmentValue 'POSTGRES_PASSWORD')"

Write-Host ''
Write-Host 'MCP authentication' -ForegroundColor Green
Write-Host "  API key:         $(Get-AzdEnvironmentValue 'MCP_API_KEY')"

Write-Host ''
Write-Host 'Azure resources' -ForegroundColor Green
Write-Host "  Resource group:  $(Get-AzdEnvironmentValue 'AZURE_RESOURCE_GROUP')"
Write-Host "  Container group: $(Get-AzdEnvironmentValue 'AZURE_CONTAINER_GROUP_NAME')"

Write-Host ''
Write-Host 'The bootstrap and initial HTTPS certificate issuance can take several minutes. Inspect the Odoo and Caddy container logs in the Azure portal if an endpoint is not ready yet.'
