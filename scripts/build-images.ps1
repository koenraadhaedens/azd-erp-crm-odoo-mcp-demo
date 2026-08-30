param(
    [string]$Registry = 'acrdefcontainer',
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$')]
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required when BUILD_IMAGES=true. Install it and run az login.'
}

$builds = @(
    @{ Image = "odoo:$Tag"; Alias = 'odoo:18.0'; Context = 'src/odoo'; Dockerfile = 'src/odoo/Dockerfile' },
    @{ Image = "postgres:$Tag"; Alias = 'postgres:16'; Context = 'src/postgres'; Dockerfile = 'src/postgres/Dockerfile' },
    @{ Image = "odoo-mcp:$Tag"; Alias = 'odoo-mcp:latest'; Context = 'src/odoo-mcp'; Dockerfile = 'src/odoo-mcp/Dockerfile' },
    @{ Image = "caddy-odoo:$Tag"; Alias = 'caddy-odoo:latest'; Context = 'src/caddy'; Dockerfile = 'src/caddy/Dockerfile' }
)

Push-Location $root
try {
    foreach ($build in $builds) {
        Write-Host "Building $($build.Image) in $Registry..." -ForegroundColor Cyan
        az acr build `
            --registry $Registry `
            --image $build.Image `
            --image $build.Alias `
            --file $build.Dockerfile `
            $build.Context `
            --output none `
            --only-show-errors
        if ($LASTEXITCODE -ne 0) {
            throw "ACR build failed for $($build.Image)."
        }
    }
}
finally {
    Pop-Location
}
