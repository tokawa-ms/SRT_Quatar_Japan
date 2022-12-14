/* uniqueness*/
var uniqueness = uniqueString(resourceGroup().id)
var sharedRules = loadJsonContent('./shared-nsg-rules.json', 'securityRules')

/* NSG */
resource qcnsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'qcnsg-${uniqueness}'
  location: location1
  properties: {
    securityRules: sharedRules
  }
}

resource jensg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'jensg-${uniqueness}'
  location: location2
  properties: {
    securityRules: sharedRules
  }
}

/* public ip*/
resource qcpublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'qcpubip-${uniqueness}'
  location: location1
  sku:{
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: 'qcgw-${uniqueness}'
    }
  }
}

resource jepublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'jepubip-${uniqueness}'
  location: location2
  sku:{
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: 'jegw-${uniqueness}'
    }
  }
}

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
  name: 'qatar-nic-${uniqueness}'
  location: location1
  properties: {
    ipConfigurations: [
      {
        name: 'qatar-ip-${uniqueness}'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets',virtualNetwork1.name,'Subnet-1')
          }
          publicIPAddress:{
            id: qcpublicIPAddress.id
          }
        }
      }
    ]
    networkSecurityGroup:{
      id: qcnsg.id
    }
  }
}

resource networkInterface2 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'japaneast-nic-${uniqueness}'
  location: location2
  properties: {
    ipConfigurations: [
      {
        name: 'japaneast-ip-${uniqueness}'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets',virtualNetwork2.name,'Subnet-1')
          }
          publicIPAddress:{
            id: jepublicIPAddress.id
          }
        }
      }
    ]
    networkSecurityGroup:{
      id: jensg.id
    }
  }
}

/* diag storage*/
resource qatarstg 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'qcdiag${uniqueness}'
  location: location1
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource japaneaststg 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'jediag${uniqueness}'
  location: location2
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

/* Deploy VM*/
param adminusername string = 'hvroot'

@secure()
param adminkey string

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminusername}/.ssh/authorized_keys'
        keyData: adminkey
      }
    ]
  }
}

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
      vmSize: 'Standard_D4s_v3'
    }
    osProfile: {
      computerName: 'srtgatewayqatar${uniqueness}'
      adminUsername: adminusername
      adminPassword: adminkey
      linuxConfiguration: linuxConfiguration
    }
    storageProfile: {
      imageReference: {
        publisher: 'haivisionsystemsinc1580780591922'
        offer: 'haivision-srt-gateway'
        sku: 'srt-gateway-3-7-5-mi'
        version: 'latest'
      }
      osDisk: {
        name: 'qcosdisk${uniqueness}'
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
      vmSize: 'Standard_D4s_v3'
    }
    osProfile: {
      computerName: 'srtgatewayjapan${uniqueness}'
      adminUsername: adminusername
      adminPassword: adminkey
      linuxConfiguration: linuxConfiguration
    }
    storageProfile: {
      imageReference: {
        publisher: 'haivisionsystemsinc1580780591922'
        offer: 'haivision-srt-gateway'
        sku: 'srt-gateway-3-7-5-mi'
        version: 'latest'
      }
      osDisk: {
        name: 'jeosdisk${uniqueness}'
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
