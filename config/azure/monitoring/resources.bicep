@description('Region of the existing GearPass Web VM.')
param location string = 'swedencentral'
param webVmName string = 'vm-gearpass-web'
param workspaceName string = 'law-gearpass-monitor'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json('0.05')
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource rule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-gearpass-syslog'
  location: location
  kind: 'Linux'
  properties: {
    dataSources: {
      syslog: [
        {
          name: 'gearpass'
          streams: ['Microsoft-Syslog']
          facilityNames: ['local0', 'local1', 'local2']
          logLevels: ['Info', 'Notice', 'Warning', 'Error', 'Critical', 'Alert', 'Emergency']
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: workspace.id
          name: 'gearpassLogs'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-Syslog']
        destinations: ['gearpassLogs']
      }
    ]
  }
}

resource web 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: webVmName
}

resource association 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'gearpass'
  scope: web
  properties: {
    dataCollectionRuleId: rule.id
  }
}

resource agent 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: 'AzureMonitorLinuxAgent'
  parent: web
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, 'gearpass-finops-monitor')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'GearPass - CPU, RAM i API'
    category: 'workbook'
    sourceId: workspace.id
    serializedData: replace(loadTextContent('workbook.json'), '__WORKSPACE_ID__', workspace.id)
  }
}

output workspaceResourceId string = workspace.id
output workbookResourceId string = workbook.id

// Forward only project telemetry to Web. API and DB ingress rules stay at their existing scopes.
resource webNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: 'nsg-gearpass-web'
}
resource telemetryIn 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  parent: webNsg
  name: 'AllowPrivateTelemetry'
  properties: {
    direction: 'Inbound'
    priority: 130
    protocol: 'Tcp'
    access: 'Allow'
    sourceAddressPrefixes: ['10.79.0.68/32', '10.79.0.132/32']
    sourcePortRange: '*'
    destinationAddressPrefix: '10.79.0.4/32'
    destinationPortRange: '5514'
  }
}
resource privateNsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = [for role in ['app', 'data']: {
  name: 'nsg-gearpass-${role}'
}]
resource telemetryOut 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = [for (role, i) in ['app', 'data']: {
  parent: privateNsgs[i]
  name: 'AllowPrivateTelemetry'
  properties: {
    direction: 'Outbound'
    priority: 130
    protocol: 'Tcp'
    access: 'Allow'
    sourceAddressPrefix: role == 'app' ? '10.79.0.68/32' : '10.79.0.132/32'
    sourcePortRange: '*'
    destinationAddressPrefix: '10.79.0.4/32'
    destinationPortRange: '5514'
  }
}]
