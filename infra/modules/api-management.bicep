param environmentName string
param location string
param tags object
param publisherName string
param publisherEmail string
param tenantId string
param entraAppClientId string
param mcpBackendUrl string

@secure()
param mcpApiKey string

var serviceName = 'apim-${take(toLower(replace(environmentName, '-', '')), 24)}-${uniqueString(subscription().id, environmentName)}'
var gatewayUrl = 'https://${serviceName}.azure-api.net'
var protectedResourceUrl = '${gatewayUrl}/.well-known/oauth-protected-resource/odoo-mcp/mcp'

resource apiManagement 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: serviceName
  location: location
  tags: tags
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource backendAuthorization 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apiManagement
  name: 'odoo-mcp-backend-authorization'
  properties: {
    displayName: 'odoo-mcp-backend-authorization'
    secret: true
    value: 'Bearer ${mcpApiKey}'
  }
}

resource mcpApi 'Microsoft.ApiManagement/service/apis@2025-03-01-preview' = {
  parent: apiManagement
  name: 'odoo-mcp'
  properties: {
    apiType: 'mcp'
    type: 'mcp'
    displayName: 'Odoo ERP CRM MCP'
    description: 'Entra-protected passthrough to the disposable Odoo demo.'
    path: 'odoo-mcp'
    protocols: [
      'https'
    ]
    serviceUrl: mcpBackendUrl
    subscriptionRequired: false
  }
}

resource mcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: mcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '<policies><inbound><base /><validate-azure-ad-token tenant-id="${tenantId}" header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized"><audiences><audience>${entraAppClientId}</audience><audience>api://${entraAppClientId}</audience></audiences><required-claims><claim name="scp" match="any" separator=" "><value>mcp.access</value></claim></required-claims></validate-azure-ad-token><rate-limit-by-key calls="60" renewal-period="60" counter-key="@(context.Request.IpAddress)" /><set-header name="Authorization" exists-action="override"><value>{{odoo-mcp-backend-authorization}}</value></set-header></inbound><backend><forward-request /></backend><outbound><base /></outbound><on-error><choose><when condition="@(context.Response.StatusCode == 401)"><return-response><set-status code="401" reason="Unauthorized" /><set-header name="WWW-Authenticate" exists-action="override"><value>Bearer error="invalid_token", resource_metadata="${protectedResourceUrl}"</value></set-header></return-response></when></choose><base /></on-error></policies>'
  }
  dependsOn: [
    backendAuthorization
  ]
}

resource metadataApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apiManagement
  name: 'odoo-mcp-oauth-metadata'
  properties: {
    apiType: 'http'
    displayName: 'Odoo MCP OAuth metadata'
    path: ''
    protocols: [
      'https'
    ]
    subscriptionRequired: false
  }
}

resource metadataOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: metadataApi
  name: 'get-protected-resource-metadata'
  properties: {
    displayName: 'Get Odoo MCP protected resource metadata'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-protected-resource/odoo-mcp/mcp'
    templateParameters: []
    responses: [
      {
        statusCode: 200
      }
    ]
  }
}

resource metadataPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-05-01' = {
  parent: metadataOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '<policies><inbound><return-response><set-status code="200" reason="OK" /><set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header><set-body>{"resource":"${gatewayUrl}/odoo-mcp/mcp","authorization_servers":["https://login.microsoftonline.com/${tenantId}/v2.0"],"scopes_supported":["api://${entraAppClientId}/mcp.access"],"bearer_methods_supported":["header"]}</set-body></return-response></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

output serviceName string = apiManagement.name
output gatewayUrl string = gatewayUrl
output mcpUrl string = '${gatewayUrl}/odoo-mcp/mcp'
output protectedResourceUrl string = protectedResourceUrl
