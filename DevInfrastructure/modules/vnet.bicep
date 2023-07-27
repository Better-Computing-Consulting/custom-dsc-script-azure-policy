
@description('Project ID for resource names.')
param projectId string = 'demo'

@description('Location for all resources.')
param location string = resourceGroup().location

var firstSubnet = 'default'
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: '${projectId}-VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.23.0.0/16'
      ]
    }
    subnets: [
      {
        name: firstSubnet
        properties: {
          addressPrefix: '172.23.3.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                'westus'
              ]
            }
          ]
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    enableDdosProtection: false
  }
  resource defaultSubnet 'subnets' existing = {
    name: firstSubnet
  }
}

output subnetId string = virtualNetwork::defaultSubnet.id
