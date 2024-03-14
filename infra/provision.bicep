@minLength(1)
@maxLength(64)
@description('Name of the resource group that will contain all the resources')
param resourceGroupName string = 'aspiretoacarg'

@minLength(1)
@description('Primary location for all resources')
param location string = 'centralus'

@minLength(5)
@maxLength(50)
@description('Name of the Azure Container Registry resource into which container images will be published')
param containerRegistryName string = 'aspiretoacacr'

@minLength(1)
@maxLength(64)
@description('Name of the identity used by the apps to access Azure Container Registry')
param identityName string = 'aspiretoacaid'

@description('CPU cores allocated to a single container instance, e.g., 0.5')
param containerCpuCoreCount string = '0.25'

@description('Memory allocated to a single container instance, e.g., 1Gi')
param containerMemory string = '0.5Gi'

var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, location))

@description('The silo image to deploy')
param siloImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('The web image to deploy')
param webImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// log analytics
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'logs${resourceToken}'
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

// the container apps environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: 'acae${resourceToken}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }

    // BREAKS IT  ////
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    //////////////////
  }
}

// the container registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

// identity for the container apps
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

var principalId = identity.properties.principalId

// azure system role for setting up acr pull access
var acrPullRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

// allow acr pulls to the identity used for the aca's
resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry // Use when specifying a scope that is different than the deployment scope
  name: guid(subscription().id, resourceGroup().id, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    principalType: 'ServicePrincipal'
    principalId: principalId
  }
}

// Azure storage
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: take('st${resourceToken}', 24)
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    // allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
  }

  resource tables 'tableServices' = {
    name: 'default'
  }
}

var clusteringKey = listKeys(storage.id, '2019-06-01').keys[0].value
var endpoint = storage.properties.primaryEndpoints.table
var clusteringConnString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${clusteringKey};TableEndpoint=${endpoint};'

var clusterEnvs = [
  {
    name: 'ConnectionStrings__clustering'
    secretRef: 'cluster-key'
  }
  {
    name: 'Orleans_ClusterId'
    value: 'e1e07362496146de9bc91390f7641de8'
  }
  {
    name: 'Orleans__Clustering__ProviderType'
    value: 'AzureTableStorage'
  }
  {
    name: 'Orleans__Clustering__ServiceKey'
    value: 'clustering'
  }
  {
    name: 'Orleans__EnableDistributedTracing'
    value: 'true'
  }
]

var appPort = 3000

// silo - the app's back-end
resource silo 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'silo'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identity.id}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: appPort
      }
      dapr: { enabled: false }
      registries: [
        {
          server: '${containerRegistryName}.azurecr.io'
          identity: identity.id
        }
      ]
      secrets: [
        {
          name: 'cluster-key'
          value: clusteringConnString
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 2
        maxReplicas: 2
      }
      serviceBinds: []
      containers: [
        {
          image: siloImage
          name: 'silo'
          env: concat([
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:${appPort}'
            }
          ], clusterEnvs)
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
          }
        }
      ]
    }
  }
}

// web - the app's front end
resource web 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'web'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identity.id}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: appPort
        transport: 'http'
      }
      dapr: { enabled: false }
      registries: [
        {
          server: '${containerRegistryName}.azurecr.io'
          identity: identity.id
        }
      ]
      secrets: [
        {
          name: 'cluster-key'
          value: clusteringConnString
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 2
        maxReplicas: 2
      }
      containers: [
        {
          image: webImage
          name: 'web'
          env: concat([
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:${appPort}'
            }
          ], clusterEnvs)
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
          }
        }
      ]
    }
  }
}

var webUri = 'https://${web.properties.configuration.ingress.fqdn}/'

// Create an app insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai${resourceToken}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// // Create webtest
// resource webTest 'Microsoft.Insights/webtests@2022-06-15' = {
//   name: 'wb${resourceToken}'
//   location: location
//   kind: 'ping'
//   tags: {
//     'hidden-link:${appInsights.id}': 'Resource'
//   }
//   properties: {
//     Configuration: {
//       WebTest: replace(loadTextContent('./webtest.xml'), '##WEB_URI##', '${webUri}?name=webtest')
//     }
//     Enabled: true
//     Frequency: 300
//     Kind: 'ping'
//     Locations: [
//       {
//         Id: 'us-tx-sn1-azr'
//       }
//       {
//         Id: 'us-il-ch1-azr'
//       }
//       {
//         Id: 'us-ca-sjc-azr'
//       }
//     ]
//     Name: 'webtest'
//     RetryEnabled: false
//     SyntheticMonitorId: 'webtest-id'
//     Timeout: 30
//   }
// }

// Output the host name of the web app
output webUri string = webUri
