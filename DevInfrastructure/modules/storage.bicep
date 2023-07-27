@description('Location for all resources.')
param location string = resourceGroup().location

param subnetId string

param publicIP string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: take('${replace(toLower(resourceGroup().name), '-','')}storageacc${uniqueString(resourceGroup().id)}', 24) 
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      ipRules: [
        {
          action: 'Allow'
          value: publicIP
        }
      ]
      virtualNetworkRules: [
        {
          id: subnetId
          action: 'Allow'
        }
      ]
      defaultAction: 'Deny'
    }
    accessTier: 'Hot'
  }
  resource blobService 'blobServices' = {
    name: 'default'
    resource container 'containers' = {
      name: 'scripts'
      properties: {
        publicAccess: 'Container'
      }
    }
  }
}
