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
    $lastBuiltTag = Get-AzdValue 'LAST_BUILT_IMAGE_TAG'
    if ($lastBuiltTag -ne $imageTag) {
        & "$PSScriptRoot/build-images.ps1" -Registry $registryName -Tag $imageTag
        if ($LASTEXITCODE -ne 0) { throw 'One or more ACR image builds failed.' }
        azd env set LAST_BUILT_IMAGE_TAG $imageTag
    }
    azd env set ODOO_IMAGE "$registryServer/odoo:$imageTag"
    azd env set POSTGRES_IMAGE "$registryServer/postgres:$imageTag"
    azd env set MCP_IMAGE "$registryServer/odoo-mcp:$imageTag"
    azd env set CADDY_IMAGE "$registryServer/caddy:$imageTag"
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
        azd env set CADDY_IMAGE "$registryServer/caddy:latest"
    }
}

$existingUsername = azd env get-value ACR_USERNAME 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($existingUsername)) {
    $enteredUsername = Read-Host 'ACR pull username [acrdefcontainer]'
    if ([string]::IsNullOrWhiteSpace($enteredUsername)) {
        $enteredUsername = 'acrdefcontainer'
    }
    azd env set ACR_USERNAME $enteredUsername
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to save ACR_USERNAME in the selected azd environment.'
    }
}

$existingPassword = azd env get-value ACR_PASSWORD 2>$null
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existingPassword)) {
    exit 0
}

Write-Host 'A pull password or repository-scoped token is required for acrdefcontainer.azurecr.io.' -ForegroundColor Cyan
$securePassword = Read-Host 'ACR pull password/token' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if ([string]::IsNullOrWhiteSpace($plainPassword)) {
        throw 'The ACR pull password/token cannot be empty.'
    }
    azd env set ACR_PASSWORD $plainPassword
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to save ACR_PASSWORD in the selected azd environment.'
    }
}
finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    $plainPassword = $null
}
