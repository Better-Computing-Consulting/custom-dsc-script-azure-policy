@description('Location for all resources.')
param location string = resourceGroup().location

@description('Size of the VM.')
@allowed([
  'Standard_DS1_v2'
  'Standard_D2s_v3'
  'Standard_D8s_v5'
  'Standard_F8s_v2'
  'Standard_D8as_v4'
  'Standard_D16s_v5'
])
param vmSize string = 'Standard_DS1_v2'

@description('VM name prefix')
param vmName string = 'vm-a'

@description('Number of VMs to deploy.')
param vmCount int = 1

@description('VM administrator username needed for vmType hostPool or firstVersion')
@secure()
param adminUserName string

@description('VM administrator password needed for vmType hostPool or firstVersion')
@secure()
param adminPassword string

@description('Id of destination subnet for the VM')
param subnetId string

param publicIP string

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, vmCount): {
  name: '${vmName}-${i}' 
  location: location
  identity:{
    type: 'SystemAssigned' 
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface[i].id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    storageProfile:{
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-22h2-avd'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: '${vmName}-${i}'
      adminUsername: adminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: 'Manual'
          assessmentMode: 'ImageDefault'
        }
        enableVMAgentPlatformUpdates: false
      }
      allowExtensionOperations: true
    }
  }
}]

resource AzurePolicyforWindows 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = [for i in range(0, vmCount): {
  name: 'AzurePolicyforWindows'
  parent: virtualMachine[i]
  location: location
  properties: {
    publisher: 'Microsoft.GuestConfiguration'
    type: 'ConfigurationforWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}]

resource AADLoginForWindows 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = [for i in range(0, vmCount): {
  name: 'AADLoginForWindows'
  parent: virtualMachine[i]
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}] 

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = [for i in range(0, vmCount): {
  name: '${vmName}-${i}-VMNic' 
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig${vmName}-${i}'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: publicIpAddress[i].id
            properties: {
              deleteOption: 'Delete'
            }
          }
          
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup[i].id
    }
  }
}]

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-11-01' = [for i in range(0, vmCount): {
  name: '${vmName}-${i}-VMNic-NSG' 
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: publicIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority:  300
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}]

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-11-01'= [for i in range(0, vmCount): {
  name: '${vmName}-${i}-VMNic-PublicIP'
  location: location
  properties: {
    deleteOption: 'Delete'
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}]

var vmIds = [for i in range(0, vmCount): virtualMachine[i].id ]
output vmIds string = string(vmIds)
