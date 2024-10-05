// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Bicep template to create the resources for a demo of Azure Site Recovery (ASR) for VMs.
DESCRIPTION: This Bicep file is used to deploy a VM in a source region and configure ASR to replicate the VM to a target region.
AUTHOR/S: David Smith (CSA FSI)
*/

// Scope
targetScope = 'subscription'

// Parameters & variables (see deployparam.yaml file)
@description('Deployment Prefix')
param parDeploymentPrefix string
@description('Source VM Region')
param sourceLocation string
@description('Target VM Region')
param targetLocation string
@secure()
param vmAdminPassword string
@description('VNet configurations for source')
param sourceVnetConfig object
@description('VNet configurations for target')
param targetVnetConfig object
param vmConfigs array

// Resources
@description('Resource Groups for source and target')
resource sourceRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${parDeploymentPrefix}-source-${sourceLocation}-rg'
  location: sourceLocation
}
@description('Resource Groups for source and target')
resource targetRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${parDeploymentPrefix}-target-${targetLocation}-rg'
  location: targetLocation
}

@description('Log Analytics Account in Source Region')
module logAnalytics './MODULES/MONITORING/monitor.bicep' = {
  name: 'loganalytics'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
  }
}

@description('ASR Vault in the target region')
module asrvault './MODULES/SITERECOVERY/asrvault.bicep' = {
  name: 'asrvault'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

@description('Backup Vault in the source region')
module backupvault './MODULES/SITERECOVERY/asrvault.bicep' = {
  name: 'backupvault'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

@description('Automation Account for ASR')
module automationacct './MODULES/SITERECOVERY/automation.bicep' = {
  name: 'asr-automationaccount'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}

@description('Storage account for ASR cache')
module storageacct './MODULES/STORAGE/storage.bicep' = {
  name: 'storageacct-${sourceLocation}'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}

@description('VNet configurations for source and target')
module sourceVnet './MODULES/NETWORK/vnet.bicep' = {
  name: 'vnet-${sourceLocation}'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    vnetConfig: sourceVnetConfig
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}
module targetVnet './MODULES/NETWORK/vnet.bicep' = {
  name: 'vnet-${targetLocation}'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    vnetConfig: targetVnetConfig
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

module peerSourceToTarget './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${sourceVnet.name}-${targetVnet.name}'
  scope: sourceRG
  params: {
    parHomeNetworkName: sourceVnet.outputs.name
    parRemoteNetworkId: targetVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}
module peerTargetToSource './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${targetVnet.name}-${sourceVnet.name}'
  scope: targetRG
  params: {
    parHomeNetworkName: targetVnet.outputs.name
    parRemoteNetworkId: sourceVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}

@description('Azure Bastion in the source region')
module bastion './MODULES/BASTION/bastion.bicep' = {
  name: 'bastion'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    bastionSubnetId: resourceId(
      subscription().subscriptionId,
      sourceRG.name,
      'Microsoft.Network/virtualNetworks/subnets',
      sourceVnet.outputs.name,
      'AzureBastionSubnet'
    )
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
    sourceVnet
    peerSourceToTarget
    peerTargetToSource
  ]
}

@description('Key Vault in the source region')
module kv './MODULES/SECURITY/keyvault.bicep' = {
  name: 'keyvault'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    secretName: 'vmAdminPassword'
    vmAdminPassword: vmAdminPassword
    userPrincipalId: 'f07e7ee2-d553-4c07-ba96-369a7500f87b'
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

@description('Load Balancer')
module lbSource './MODULES/NETWORK/loadbalancer.bicep' = {
  name: 'lbSource'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
    sourceVnet
  ]
}
module lbTarget './MODULES/NETWORK/loadbalancer.bicep' = {
  name: 'lbTarget'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
    sourceVnet
  ]
}

@description('VM deployments')
var vmAdminUsername = 'azadmin'
module vmDeployments './MODULES/VIRTUALMACHINE/vm.bicep' = [
  for vmConfig in vmConfigs: if (vmConfig.deploy) {
    name: 'vm-${vmConfig.nameSuffix}'
    scope: sourceRG
    dependsOn: [
      sourceVnet
      lbSource
      lbTarget
    ]
    params: {
      namePrefix: parDeploymentPrefix
      nameSuffix: vmConfig.nameSuffix
      purpose: vmConfig.purpose
      vmSize: vmConfig.vmSize
      osDiskSize: vmConfig.osDiskSize
      dataDiskSize: vmConfig.dataDiskSize
      osType: vmConfig.osType
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      imagePublisher: vmConfig.imagePublisher
      imageOffer: vmConfig.imageOffer
      imageSku: vmConfig.imageSku
      imageVersion: vmConfig.imageVersion
      publicIp: vmConfig.publicIp
      subnetId: sourceVnet.outputs.subnets[0].id
      backendAddressPools: (vmConfig.purpose == 'web') ? lbSource.outputs.backendAddressPools : [null]
      logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    }
  }
]

@description('Traffic Manager profile for the web site on the source VM')
module trafficManager './MODULES/NETWORK/trafficmanager.bicep' = {
  scope: sourceRG
  name: 'myTrafficManagerProfile'
  params: {
    namePrefix: parDeploymentPrefix
    endpoint1Target: lbSource.outputs.fqdn
    endpoint2Target: lbTarget.outputs.fqdn
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}

// // Output
output vmUserName string = vmAdminUsername
output fqdn string = trafficManager.outputs.trafficManagerfqdn
// output vmNames string = vmNames
