targetScope = 'subscription'

@description('Name of the azd environment receiving the generated demo credentials.')
param environmentName string

@description('Azure region selected for the application deployment.')
param location string

// This intentionally empty deployment creates an azd provisioning boundary.
// After its preprovision hook runs, azd reloads the environment before starting
// the dependent application layer.
output CREDENTIALS_LAYER_READY string = '${environmentName}:${location}'
