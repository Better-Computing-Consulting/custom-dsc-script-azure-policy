
@description('Location for all resources.')
param location string = resourceGroup().location

@description('The Azure Active Directory tenant ID that should be used for authenticating requests to the key vault.')
param tenantId string

@description('The object ID of a user in the Azure Active Directory tenant for the vault.')
param keyVaultUser string

@description('Public IP with access to the keyVault')
param publicIP string

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' =  {
  name: take('${replace(toLower(resourceGroup().name), '-','')}keyvault${uniqueString(resourceGroup().id)}', 24)
  location: location
  properties: {
    enabledForTemplateDeployment: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: publicIP
        }
      ]
    }
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: keyVaultUser
        permissions: {
          secrets: [
            'all'
          ]
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
