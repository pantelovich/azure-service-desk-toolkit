targetScope = 'subscription'

@description('Azure region used for the support evidence resources.')
param location string = 'uksouth'

@description('Short project name used in resource names.')
param projectName string = 'servicedesk'

@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

var resourceGroupName = 'rg-${projectName}-${environment}'

resource supportResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: {
    project: 'azure-service-desk-toolkit'
    environment: environment
    owner: 'Pantelis'
    managedBy: 'Bicep'
  }
}

module supportEvidence './modules/support-evidence.bicep' = {
  name: 'support-evidence-${environment}'
  scope: supportResourceGroup
  params: {
    environment: environment
    location: location
  }
}

output resourceGroupName string = supportResourceGroup.name
output storageAccountName string = supportEvidence.outputs.storageAccountName
output reportContainerName string = supportEvidence.outputs.reportContainerName
output logAnalyticsWorkspaceName string = supportEvidence.outputs.logAnalyticsWorkspaceName

