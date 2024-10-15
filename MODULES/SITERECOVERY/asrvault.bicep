// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Site Recovery Vault.
DESCRIPTION: This module will create a deployment which will create the Site Recovery Vault in the target region for an ASR Demo
AUTHOR/S: David Smith (CSA FSI)
*/

// Parameters & variables
@description('ASR Vault Name, Location and SKU')
param namePrefix string
var nameSuffix = 'asrvault'
var location = resourceGroup().location
var Name = '${namePrefix}-${location}-${nameSuffix}'
param logAnalyticsWorkspaceId string

// Resources
@description('ASR Vault configuration in the target region')
resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: Name
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
    redundancySettings: {
      crossRegionRestore: 'Enabled'
      standardTierStorageRedundancy: 'GeoRedundant'
    }
    monitoringSettings: {
      azureMonitorAlertSettings: {
        alertsForAllFailoverIssues: 'Enabled'
        alertsForAllJobFailures: 'Enabled'
        alertsForAllReplicationIssues: 'Enabled'
      }
      classicAlertSettings: {
        alertsForCriticalOperations: 'Disabled'
        emailNotificationsForSiteRecovery: 'Disabled'
      }
    }
  }
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
}

// Backup Configuration & Policies
resource backupRsvConfig 'Microsoft.RecoveryServices/vaults/BackupConfig@2022-02-01' = {
  parent: recoveryServicesVault
  name: 'vaultconfig'
  properties: {
    enhancedSecurityState: 'Disabled'
    isSoftDeleteFeatureStateEditable: true
    softDeleteFeatureState: 'Disabled'
  }
}

resource backupVlt 'Microsoft.DataProtection/backupVaults@2022-11-01-preview' = {
  name: '${Name}-backupVault'
  location: location
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type: 'GeoRedundant'
      }
    ]
  }
}

// replicaitonPolicies
resource replicationPolicies 'Microsoft.RecoveryServices/vaults/replicationPolicies@2024-04-01' = {
  name: '24-hour-retention-policy'
  parent: recoveryServicesVault
  properties: {
    providerSpecificInput: {
      instanceType: 'A2A'
      multiVmSyncStatus: 'Disable'
    }
  }
}

resource diagsettingsbackup 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${recoveryServicesVault.name}-backupdiag'
  scope: recoveryServicesVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AzureBackupReport'
        enabled: true
      }
      {
        category: 'CoreAzureBackup'
        enabled: true
      }
      {
        category: 'AddonAzureBackupJobs'
        enabled: true
      }
      {
        category: 'AddonAzureBackupAlerts'
        enabled: true
      }
      {
        category: 'AddonAzureBackupPolicy'
        enabled: true
      }
      {
        category: 'AddonAzureBackupStorage'
        enabled: true
      }
      {
        category: 'AddonAzureBackupProtectedInstance'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Health'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
  }
}

resource diagsettingssiterecovery 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${recoveryServicesVault.name}-siterecoverydiag'
  scope: recoveryServicesVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AzureSiteRecoveryJobs'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryEvents'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryReplicatedItems'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryReplicationStats'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryRecoveryPoints'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryReplicationDataUploadRate'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryProtectedDiskDataChurn'
        enabled: true
      }
      // {
      //   category: 'AzureSiteRecoveryReplicatedItemsDetails'
      //   enabled: true
      // }
    ]
    metrics: [
      {
        category: 'Health'
        enabled: false
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
  }
}

// Output
@description('Output the vault name')
output vaultName string = recoveryServicesVault.name
