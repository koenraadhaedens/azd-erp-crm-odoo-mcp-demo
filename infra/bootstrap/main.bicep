targetScope = 'subscription'

@description('Name of the azd environment receiving the generated demo credentials.')
param environmentName string

@description('Azure region selected for the application deployment.')
param location string

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
