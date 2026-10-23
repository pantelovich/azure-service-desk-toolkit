param location string
param environment string

var resourceSuffix = uniqueString(resourceGroup().id, environment)
var storageAccountName = 'stsd${resourceSuffix}'

resource reportStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: {
    project: 'azure-service-desk-toolkit'
    environment: environment
    dataClassification: 'support-data'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: reportStorage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: true
  }
}

resource reportContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'support-reports'
  properties: {
    publicAccess: 'None'
  }
}

resource supportLogs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-servicedesk-${environment}-${resourceSuffix}'
  location: location
  tags: {
    project: 'azure-service-desk-toolkit'
    environment: environment
  }
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

output storageAccountName string = reportStorage.name
output reportContainerName string = reportContainer.name
output logAnalyticsWorkspaceName string = supportLogs.name

