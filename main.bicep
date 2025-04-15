@description('The Azure region into which the resources should be deployed.')
param location string

@secure()
@description('The administrator login username for the SQL server.')
param sqlServerAdministratorLogin string

@secure()
@description('The administrator login password for the SQL server.')
param sqlServerAdministratorLoginPassword string

@description('The name and tier of the SQL database SKU.')
param sqlDatabaseSku object = {
  name: 'Standard'
  tier: 'Standard'
}

@description('The name of the environment. This must be Development or Production.') 
@allowed([
  'Development'
  'Production'
])
param environmentName string = 'Development' // default to Development

@description('The name of the audit storage account SKU.')
param auditStorageAccountSkuName string = 'Standard_LRS' // default to Standard_LRS

var sqlServerName = 'teddy${location}${uniqueString(resourceGroup().id)}'
var sqlDatabaseName = 'TeddyBear'

var auditingEnabled = environmentName == 'Production' // when in production, enable auditing
var auditStorageAccountName = take('bearaudit${location}${uniqueString(resourceGroup().id)}', 24) // max length for storage account name is 24 characters
// the take function is used to ensure the name is within the limit, it trims the end off the string to ensure that the name is valid

resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlServerAdministratorLogin
    administratorLoginPassword: sqlServerAdministratorLoginPassword
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: sqlDatabaseSku
}
resource auditStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (auditingEnabled) { // only create if auditing is enabled i.e in production
  name: auditStorageAccountName
  location: location // location is the same as the SQL serverß
  sku: {
    name: auditStorageAccountSkuName // took the default value from the parameter
  }
  kind: 'StorageV2'  
}
resource sqlServerAudit 'Microsoft.Sql/servers/auditingSettings@2024-05-01-preview' = if (auditingEnabled) {
  parent: sqlServer
  name: 'default' 
  properties: {
    state: 'Enabled'
    storageEndpoint: environmentName == 'Production' ? auditStorageAccount.properties.primaryEndpoints.blob : '' // only set when in production
    // the storage endpoint is set to the blob endpoint of the storage account
    // the ? ternary operator to ensure that their values are always valid. If you don't do this, Azure Resource Manager evaluates the expression values before it evaluates the resource deployment condition and returns an error, because the storage account can't be found.
    storageAccountAccessKey: environmentName == 'Production' ? auditStorageAccount.listKeys().keys[0].value : ''
  }
}
