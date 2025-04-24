using 'provision.bicep'

param resourceGroupName = readEnvironmentVariable('RESOURCE_GROUP', 'acatoaspirerg')
param location = readEnvironmentVariable('LOCATION', 'westus')
param containerRegistryName = readEnvironmentVariable('CONTAINER_REGISTRY', 'acatoaspirecr')
param identityName = readEnvironmentVariable('IDENTITY', 'acatoaspireid')
param siloImage = readEnvironmentVariable('SILO_IMAGE', 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest')
param webImage = readEnvironmentVariable('WEB_IMAGE', 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest')
param replicas = int(readEnvironmentVariable('REPLICAS', '1'))
