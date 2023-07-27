param location string = 'westus'

param kvName string

param vmName string

param datestamp string = utcNow('yyyyMMddHHmm')

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kvName
}

resource virtualMachineAdministratorLoginRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '1c0163c0-47e6-4577-8991-ea5c82e286e4'
}

resource virtualMachineAdministratorLoginRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, virtualMachineAdministratorLoginRoleDefinition.id)
  properties: {
    principalId: keyVault.properties.accessPolicies[0].objectId
    roleDefinitionId: virtualMachineAdministratorLoginRoleDefinition.id
  }
}

module virtualNetwork 'modules/vnet.bicep' = {
  name: 'virtual-network-${datestamp}'
  params: {
    location: location
  }
}

var i = indexOf(keyVault.properties.networkAcls.ipRules[0].value, '/')
var publicIP = take(keyVault.properties.networkAcls.ipRules[0].value, i)

module storage 'modules/storage.bicep' = {
  name: 'storage-account-${datestamp}'
  params: {
    location: location
    subnetId: virtualNetwork.outputs.subnetId
    publicIP: publicIP
  }  
}

module virtualMachine 'modules/vm.bicep' = {
  name: 'virtual-machine-${datestamp}'
  params: {
    location: location
    vmName: vmName
    adminUserName: keyVault.getSecret('adminUserName')
    adminPassword: keyVault.getSecret('adminPassword')
    subnetId: virtualNetwork.outputs.subnetId
    publicIP: keyVault.properties.networkAcls.ipRules[0].value
  }
}

output outVMs string = virtualMachine.outputs.vmIds
