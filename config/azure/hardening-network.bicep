@description('Region of the GearPass network.')
param location string = 'swedencentral'

var networkName = 'vnet-gearpass'
var web = '10.79.0.0/26'
var app = '10.79.0.64/26'
var data = '10.79.0.128/26'

var layers = [
  {
    name: 'web'
    prefix: web
    rules: [
      { name: 'AllowInternetWeb', direction: 'Inbound', priority: 100, access: 'Allow', source: 'Internet', destination: web, ports: ['80', '443'] }
      { name: 'AllowWebToApp', direction: 'Outbound', priority: 100, access: 'Allow', source: web, destination: app, ports: ['8000'] }
      { name: 'AllowTlsCertificateRenewal', direction: 'Outbound', priority: 110, access: 'Allow', source: web, destination: 'Internet', ports: ['443'] }
    ]
  }
  {
    name: 'app'
    prefix: app
    rules: [
      { name: 'AllowWebToApp', direction: 'Inbound', priority: 100, access: 'Allow', source: web, destination: app, ports: ['8000'] }
      { name: 'DenyPublicManagement', direction: 'Inbound', priority: 110, access: 'Deny', source: 'Internet', destination: app, ports: ['22', '3389'] }
      { name: 'AllowAppToPostgres', direction: 'Outbound', priority: 100, access: 'Allow', source: app, destination: data, ports: ['5432'] }
    ]
  }
  {
    name: 'data'
    prefix: data
    rules: [
      { name: 'AllowAppToPostgres', direction: 'Inbound', priority: 100, access: 'Allow', source: app, destination: data, ports: ['5432'] }
      { name: 'DenyPublicDatabase', direction: 'Inbound', priority: 110, access: 'Deny', source: 'Internet', destination: data, ports: ['3306', '5432'] }
    ]
  }
]

var denyOther = [for direction in ['Inbound', 'Outbound']: {
  name: 'DenyOther${direction}'
  direction: direction
  priority: 4096
  access: 'Deny'
  source: '*'
  destination: '*'
  ports: ['*']
}]

resource nsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [for layer in layers: {
  name: 'nsg-gearpass-${layer.name}'
  location: location
  properties: {
    securityRules: map(concat(layer.rules, denyOther), rule => {
      name: rule.name
      properties: union({
        direction: rule.direction
        priority: rule.priority
        access: rule.access
        protocol: rule.priority == 4096 ? '*' : 'Tcp'
        sourceAddressPrefix: rule.source
        sourcePortRange: '*'
        destinationAddressPrefix: rule.destination
      }, rule.priority == 4096 ? { destinationPortRange: '*' } : { destinationPortRanges: rule.ports })
    })
  }
}]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: networkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.79.0.0/24'
      ]
    }
    subnets: [for (layer, index) in layers: {
      name: 'snet-${layer.name}'
      properties: {
        addressPrefix: layer.prefix
        networkSecurityGroup: {
          id: nsgs[index].id
        }
      }
    }]
  }
}

output virtualNetworkName string = vnet.name
