$ErrorActionPreference = 'Stop'

function Get-AzdEnvironmentValue([string]$Name) {
    $value = azd env get-value $Name 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
        return $value.Trim()
    }
    return '<not available>'
}

function Show-BootstrapLogs([string]$ResourceGroup, [string]$ContainerGroup) {
    Write-Host ''
    Write-Host 'Recent Odoo bootstrap logs:' -ForegroundColor Yellow
    az container logs `
        --resource-group $ResourceGroup `
        --name $ContainerGroup `
        --container-name 'odoo-bootstrap' `
        --tail 100 `
        --only-show-errors
}

function Wait-OdooBootstrap {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw 'Azure CLI is required to monitor Odoo initialization.'
    }
    az account show --output none --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'Azure CLI is not authenticated. Run az login and retry.'
    }

    $resourceGroup = Get-AzdEnvironmentValue 'AZURE_RESOURCE_GROUP'
    $containerGroup = Get-AzdEnvironmentValue 'AZURE_CONTAINER_GROUP_NAME'
    if ($resourceGroup -eq '<not available>' -or $containerGroup -eq '<not available>') {
        throw 'The Azure resource group or container group is missing from the azd environment.'
    }

    $timeout = [TimeSpan]::FromMinutes(20)
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $frames = @('|', '/', '-', '\')
    $frame = 0

    while ($stopwatch.Elapsed -lt $timeout) {
        $json = az container show `
            --resource-group $resourceGroup `
            --name $containerGroup `
            --output json `
            --only-show-errors 2>$null

        if ($LASTEXITCODE -eq 0 -and $json) {
            $group = $json | ConvertFrom-Json
            $bootstrap = $group.containers | Where-Object name -EQ 'odoo-bootstrap' | Select-Object -First 1
            $currentState = $bootstrap.instanceView.currentState
            if ($currentState.state -eq 'Terminated') {
                Write-Host "`r$(' ' * 100)`r" -NoNewline
                if ($currentState.exitCode -eq 0) {
                    Write-Host 'OK Odoo applications and realistic demo data are ready.' -ForegroundColor Green
                    return
                }

                Write-Host "FAILED Odoo bootstrap exited with code $($currentState.exitCode)." -ForegroundColor Red
                Show-BootstrapLogs $resourceGroup $containerGroup
                throw 'Odoo initialization failed; delivery credentials were not displayed.'
            }
        }

        $elapsed = [Math]::Floor($stopwatch.Elapsed.TotalSeconds)
        Write-Host "`r[$($frames[$frame % $frames.Count])] Installing Odoo applications and realistic demo data... ${elapsed}s" -NoNewline
        $frame++
        Start-Sleep -Seconds 5
    }

    Write-Host "`r$(' ' * 100)`r" -NoNewline
    Write-Host 'TIMEOUT Odoo bootstrap did not finish within 20 minutes.' -ForegroundColor Red
    Show-BootstrapLogs $resourceGroup $containerGroup
    throw 'Odoo initialization timed out; delivery credentials were not displayed.'
}

Write-Host ''
Wait-OdooBootstrap

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
Write-Host "  Database:                  $(Get-AzdEnvironmentValue 'ODOO_DATABASE')"
Write-Host "  Web login:                 $(Get-AzdEnvironmentValue 'ODOO_ADMIN_LOGIN')"
Write-Host "  Web login password:        $(Get-AzdEnvironmentValue 'ODOO_ADMIN_PASSWORD')"
Write-Host "  Database manager password: $(Get-AzdEnvironmentValue 'ODOO_MASTER_PASSWORD')"

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
Write-Host 'Odoo initialization is complete. Initial HTTPS certificate issuance may still take a short time.'
