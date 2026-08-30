$ErrorActionPreference = 'Stop'

function Get-AzdValue([string]$Name) {
    $value = azd env get-value $Name 2>$null
    if ($LASTEXITCODE -eq 0) { return $value.Trim() }
    return ''
}

$registryName = Get-AzdValue 'ACR_NAME'
if ([string]::IsNullOrWhiteSpace($registryName)) {
    $registryName = 'acrdefcontainer'
    azd env set ACR_NAME $registryName
}
$registryServer = "$registryName.azurecr.io"

$buildImages = Get-AzdValue 'BUILD_IMAGES'
if ([string]::IsNullOrWhiteSpace($buildImages)) {
    $buildImages = 'true'
    azd env set BUILD_IMAGES $buildImages
}

if ($buildImages -ieq 'true') {
    $imageTag = Get-AzdValue 'IMAGE_TAG'
    if ([string]::IsNullOrWhiteSpace($imageTag)) {
        $imageTag = (git rev-parse --short=12 HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($imageTag)) {
            $imageTag = Get-Date -Format 'yyyyMMddHHmmss'
        }
        azd env set IMAGE_TAG $imageTag
    }
    $imageBuildKey = "${imageTag}-realistic-demo-v1"
    $lastBuiltTag = Get-AzdValue 'LAST_BUILT_IMAGE_TAG'
    if ($lastBuiltTag -ne $imageBuildKey) {
        & "$PSScriptRoot/build-images.ps1" -Registry $registryName -Tag $imageTag
        if ($LASTEXITCODE -ne 0) { throw 'One or more ACR image builds failed.' }
        azd env set LAST_BUILT_IMAGE_TAG $imageBuildKey
    }
    azd env set ODOO_IMAGE "$registryServer/odoo:$imageTag"
    azd env set POSTGRES_IMAGE "$registryServer/postgres:$imageTag"
    azd env set MCP_IMAGE "$registryServer/odoo-mcp:$imageTag"
    azd env set CADDY_IMAGE "$registryServer/caddy-odoo:$imageTag"
}
else {
    if ([string]::IsNullOrWhiteSpace((Get-AzdValue 'ODOO_IMAGE'))) {
        azd env set ODOO_IMAGE "$registryServer/odoo:18.0"
    }
    if ([string]::IsNullOrWhiteSpace((Get-AzdValue 'POSTGRES_IMAGE'))) {
        azd env set POSTGRES_IMAGE "$registryServer/postgres:16"
    }
    if ([string]::IsNullOrWhiteSpace((Get-AzdValue 'MCP_IMAGE'))) {
        azd env set MCP_IMAGE "$registryServer/odoo-mcp:latest"
    }
    if ([string]::IsNullOrWhiteSpace((Get-AzdValue 'CADDY_IMAGE'))) {
        azd env set CADDY_IMAGE "$registryServer/caddy-odoo:latest"
    }
}
