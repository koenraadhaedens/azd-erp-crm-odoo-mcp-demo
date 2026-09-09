$ErrorActionPreference = 'Stop'

function Get-AzdValue([string]$Name) {
    $value = azd env get-value $Name 2>$null
    if ($LASTEXITCODE -eq 0) { return $value.Trim() }
    return ''
}

$tenantId = az account show --query tenantId --output tsv --only-show-errors
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tenantId)) {
    throw 'Azure CLI is not authenticated. Run az login and retry.'
}
azd env set ENTRA_TENANT_ID $tenantId

$clientId = Get-AzdValue 'ENTRA_APP_CLIENT_ID'
if (-not [string]::IsNullOrWhiteSpace($clientId)) {
    Write-Host "Using existing Entra application $clientId." -ForegroundColor Cyan
    return
}

$environmentName = Get-AzdValue 'AZURE_ENV_NAME'
$displayName = "Odoo MCP APIM demo - $environmentName"
$application = az ad app list `
    --display-name $displayName `
    --query '[0].{id:id,appId:appId}' `
    --output json `
    --only-show-errors | ConvertFrom-Json

if ($null -eq $application) {
    Write-Host "Creating Entra application '$displayName'..." -ForegroundColor Cyan
    $application = az ad app create `
        --display-name $displayName `
        --sign-in-audience AzureADMyOrg `
        --is-fallback-public-client true `
        --public-client-redirect-uris http://localhost `
        --query '{id:id,appId:appId}' `
        --output json `
        --only-show-errors | ConvertFrom-Json
}

$scopeId = az rest `
    --method GET `
    --uri "https://graph.microsoft.com/v1.0/applications/$($application.id)?`$select=api" `
    --query "api.oauth2PermissionScopes[?value=='mcp.access'].id | [0]" `
    --output tsv `
    --only-show-errors
if ([string]::IsNullOrWhiteSpace($scopeId)) {
    $scopeId = [guid]::NewGuid().ToString()
}

$body = @{
    identifierUris = @("api://$($application.appId)")
    isFallbackPublicClient = $true
    publicClient = @{ redirectUris = @('http://localhost') }
    api = @{
        requestedAccessTokenVersion = 2
        oauth2PermissionScopes = @(
            @{
                adminConsentDescription = 'Allow this client to access the Odoo MCP demo through API Management.'
                adminConsentDisplayName = 'Access the Odoo MCP demo'
                id = $scopeId
                isEnabled = $true
                type = 'User'
                userConsentDescription = 'Allow this application to access the Odoo MCP demo on your behalf.'
                userConsentDisplayName = 'Access the Odoo MCP demo'
                value = 'mcp.access'
            }
        )
    }
}
$bodyPath = [IO.Path]::GetTempFileName()
try {
    $body | ConvertTo-Json -Depth 8 | Set-Content -Path $bodyPath -Encoding utf8
    az rest `
        --method PATCH `
        --uri "https://graph.microsoft.com/v1.0/applications/$($application.id)" `
        --headers 'Content-Type=application/json' `
        --body "@$bodyPath" `
        --output none `
        --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw 'Failed to configure the Entra application.' }
}
finally {
    Remove-Item $bodyPath -Force -ErrorAction SilentlyContinue
}

azd env set ENTRA_APP_CLIENT_ID $application.appId
Write-Host "Configured Entra application $($application.appId)." -ForegroundColor Green