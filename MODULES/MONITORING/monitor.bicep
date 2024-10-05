// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Log Analytics Workspace
DESCRIPTION: This module will create a deployment which will create the Log Analytics Workspace
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
var nameSuffix = 'logs'
var location = resourceGroup().location
// var unique = substring(uniqueString(resourceGroup().id), 0, 8)
var Name = '${namePrefix}-${location}-${nameSuffix}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: Name
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
