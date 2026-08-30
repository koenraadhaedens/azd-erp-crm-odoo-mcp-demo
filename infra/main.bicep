targetScope = 'subscription'

@minLength(1)
@maxLength(40)
@description('Name of the azd environment. It is used in resource names and tags.')
param environmentName string

@description('Azure region for the resource group and ACI container group.')
param location string

@description('Odoo image mirrored in the external registry.')
param odooImage string = 'acrdefcontainer.azurecr.io/odoo:18.0'

@description('PostgreSQL image mirrored in the external registry.')
param postgresImage string = 'acrdefcontainer.azurecr.io/postgres:16'

@description('Odoo MCP server image in the external registry.')
param mcpImage string = 'acrdefcontainer.azurecr.io/odoo-mcp:latest'

@description('Caddy HTTPS reverse-proxy image in the external registry.')
param caddyImage string = 'acrdefcontainer.azurecr.io/caddy-odoo:latest'

@description('Comma-separated Odoo modules installed by the bootstrap container.')
param odooModules string = 'contacts,crm,sale_management,purchase,stock,account,project,hr,hr_expense,hr_timesheet,maintenance,fleet,mrp,website_sale,point_of_sale'

@minValue(1)
@maxValue(65535)
@description('Public TCP port exposed by the MCP server image.')
param mcpPort int = 8000

@secure()
@description('Generated PostgreSQL password. Override only when a stable demo credential is required.')
param postgresPassword string = 'Pg-${replace(newGuid(), '-', '')}!'

@secure()
@description('Generated Odoo database-manager password.')
param odooMasterPassword string = 'Master-${replace(newGuid(), '-', '')}!'

@secure()
@description('Generated Odoo administrator password used by the MCP server.')
param odooAdminPassword string = 'Admin-${replace(newGuid(), '-', '')}!'

@secure()
@description('Generated bearer/API key exposed to the MCP server image.')
param mcpApiKey string = 'Mcp-${replace(newGuid(), '-', '')}!'

var resourceGroupName = 'rg-${environmentName}'
var tags = {
  'azd-env-name': environmentName
  workload: 'odoo-mcp-demo'
  environment: 'demo'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module containerGroup 'modules/container-group.bicep' = {
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
    tags: tags
    odooImage: odooImage
    postgresImage: postgresImage
    mcpImage: mcpImage
    caddyImage: caddyImage
    odooModules: odooModules
    mcpPort: mcpPort
    postgresPassword: postgresPassword
    odooMasterPassword: odooMasterPassword
    odooAdminPassword: odooAdminPassword
    mcpApiKey: mcpApiKey
  }
}

output AZURE_RESOURCE_GROUP string = resourceGroup.name
output AZURE_CONTAINER_GROUP_NAME string = containerGroup.outputs.containerGroupName
output AZURE_CONTAINER_GROUP_FQDN string = containerGroup.outputs.fqdn
output AZURE_PORTAL_URL string = 'https://portal.azure.com/#@/resource${containerGroup.outputs.containerGroupId}'
output ODOO_URL string = containerGroup.outputs.odooUrl
output MCP_URL string = containerGroup.outputs.mcpUrl
output ODOO_DATABASE string = containerGroup.outputs.odooDatabase
output ODOO_ADMIN_LOGIN string = containerGroup.outputs.odooAdminLogin
