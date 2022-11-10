/* uniqueness*/
var uniqueness = uniqueString(resourceGroup().id)

/* Qatar Central VNET */
param location1 string = 'qatarcentral'
resource virtualNetwork1 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'qatarcentral-vnet-${uniqueness}'
  location: location1
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

/* Japan East VNET */
param location2 string = 'japaneast'
resource virtualNetwork2 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'japaneast-vnet-${uniqueness}'
  location: location2
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '10.1.0.0/24'
        }
      }
    ]
  }
}

/* VNET Peering*/
resource peering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  parent: virtualNetwork1
  name: 'qatar-japaneast'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: virtualNetwork2.id
    }
  }
}

resource peering2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  parent: virtualNetwork2
  name: 'japaneast-qatar'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: virtualNetwork1.id
    }
  }
}

/* vm nic*/
resource networkInterface1 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'qatar-nic'
  location: location1
  properties: {
    ipConfigurations: [
      {
        name: 'qatar-ip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets',virtualNetwork1.name,'Subnet-1')
          }
        }
      }
    ]
  }
}

resource networkInterface2 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'japaneast-nic'
  location: location1
  properties: {
    ipConfigurations: [
      {
        name: 'qatar-ip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets',virtualNetwork1.name,'Subnet-1')
          }
        }
      }
    ]
  }
}

/* diag storage*/
resource qatarstg 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'qatardiagstorage${uniqueness}'
  location: location1
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource japaneaststg 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'japaneastdiagstorage${uniqueness}'
  location: location2
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

/* Deploy VM*/
param adminusername string

@secure()
param adminpassword string

resource quatarVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'srt-gateway-qatar-vm-${uniqueness}'
  location: location1
  plan: {
    name: 'srt-gateway-3-7-5-mi'
    publisher: 'haivisionsystemsinc1580780591922'
    product: 'haivision-srt-gateway'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_F8s_v2'
    }
    osProfile: {
      computerName: 'srtgatewayqatar'
      adminUsername: adminusername
      adminPassword: adminpassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'haivisionsystemsinc1580780591922'
        offer: 'haivision-srt-gateway'
        sku: 'srt-gateway-3-7-5-mi'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface1.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: qatarstg.properties.primaryEndpoints.blob
      }
    }
  }
}

resource japaneastVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'srt-gateway-japaneast-vm-${uniqueness}'
  location: location2
  plan: {
    name: 'srt-gateway-3-7-5-mi'
    publisher: 'haivisionsystemsinc1580780591922'
    product: 'haivision-srt-gateway'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_F8s_v2'
    }
    osProfile: {
      computerName: 'srtgatewayqatar'
      adminUsername: adminusername
      adminPassword: adminpassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'haivisionsystemsinc1580780591922'
        offer: 'haivision-srt-gateway'
        sku: 'srt-gateway-3-7-5-mi'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface2.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: japaneaststg.properties.primaryEndpoints.blob
      }
    }
  }
}
