targetScope = 'subscription'

@description('Name of the azd environment receiving the generated demo credentials.')
param environmentName string

@description('Azure region selected for the application deployment.')
param location string

@secure()
@description('Disposable PostgreSQL password generated once for this deployment.')
param postgresPassword string = 'Pg-${replace(newGuid(), '-', '')}!'

@secure()
@description('Disposable Odoo database-manager password generated once for this deployment.')
param odooMasterPassword string = 'Master-${replace(newGuid(), '-', '')}!'

@secure()
@description('Disposable Odoo administrator password generated once for this deployment.')
param odooAdminPassword string = 'Admin-${replace(newGuid(), '-', '')}!'

@secure()
@description('Disposable MCP bearer key generated once for this deployment.')
param mcpApiKey string = 'Mcp-${replace(newGuid(), '-', '')}!'

// A layer must contain at least one ARM resource. Creating the application's
// resource group here is idempotent; the dependent layer populates it.
resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
	name: 'rg-${environmentName}'
	location: location
	tags: {
		'azd-env-name': environmentName
		workload: 'odoo-mcp-demo'
		environment: 'demo'
	}
}

// After this layer's hook and deployment finish, azd reloads the environment
// before expanding parameters for the dependent application layer.
output CREDENTIALS_LAYER_READY string = resourceGroup.name

// This repository is explicitly a disposable demo whose delivery summary prints
// these values. Normal outputs are required because azd intentionally does not
// persist @secure() outputs. Do not copy this pattern into production templates.
#disable-next-line outputs-should-not-contain-secrets
output POSTGRES_PASSWORD string = postgresPassword
#disable-next-line outputs-should-not-contain-secrets
output ODOO_MASTER_PASSWORD string = odooMasterPassword
#disable-next-line outputs-should-not-contain-secrets
output ODOO_ADMIN_PASSWORD string = odooAdminPassword
#disable-next-line outputs-should-not-contain-secrets
output MCP_API_KEY string = mcpApiKey
