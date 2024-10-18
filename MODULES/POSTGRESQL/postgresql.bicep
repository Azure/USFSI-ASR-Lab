// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Site Recovery Vault.
DESCRIPTION: This module will create a deployment which will create the Site Recovery Vault in the target region for an ASR Demo
AUTHOR/S: David Smith (CSA FSI)
*/

// Parameters & variables
@description('PostgreSQL Server Name, Location and SKU')
param namePrefix string
var nameSuffix = 'postgres'
var location = resourceGroup().location
var Name = '${namePrefix}-${location}-${nameSuffix}'
param adminUsername string
@secure()
param adminPassword string
param logAnalyticsWorkspaceId string

resource postgresqlFlexibleServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: Name
  location: location
  sku: {
    name: 'Standard_D2s_v3'
    tier: 'GeneralPurpose'
  }
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: '14'
    storage: {
      storageSizeGB: 128
    }
  }
}

resource adventureworksDB 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  name: 'adventureworks'
  parent: postgresqlFlexibleServer
}
