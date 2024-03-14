$env:SOLUTION = "orleans-aca-app"                         # Your app's name (e.g., "aspiresample42")
$env:LOCATION = "centralus"                               # Your desired Azure region (e.g., "westus")
$env:RESOURCE_GROUP = "$($env:SOLUTION.ToLower())rg"      # Resource Group name, e.g. eshopliterg
$env:CONTAINER_REGISTRY = "$($env:SOLUTION.ToLower())cr" -replace "-", ""  # Azure Container Registry name, e.g. eshoplitecr
$env:IMAGE_PREFIX = "$($env:SOLUTION.ToLower())"          # Container image name prefix, e.g. eshoplite
$env:IDENTITY = "$($env:SOLUTION.ToLower())id"            # Azure Managed Identity, e.g. eshopliteid
$env:ENVIRONMENT = "$($env:SOLUTION.ToLower())cae"        # Azure Container Apps Environment name, e.g. eshoplitecae

# Create RG
$null = az group create --location $env:LOCATION --name $env:RESOURCE_GROUP

# Deploy environment
az deployment group create --resource-group $env:RESOURCE_GROUP --template-file .\infra\provision.bicep --parameters .\infra\provision.parms.bicepparam

# Publish images
az acr login --name $env:CONTAINER_REGISTRY
$loginServer = (az acr show --name $env:CONTAINER_REGISTRY --query loginServer --output tsv)

dotnet publish -r linux-x64 `
    -p:PublishProfile=DefaultContainer `
    -p:ContainerRegistry=$loginServer

$env:SILO_IMAGE = "$($env:CONTAINER_REGISTRY).azurecr.io/orleans-repro-silo:latest"
$env:WEB_IMAGE = "$($env:CONTAINER_REGISTRY).azurecr.io/orleans-repro-client:latest"

# Update containerapps to use the latest images
az containerapp update --name silo --resource-group $env:RESOURCE_GROUP --image "$($env:CONTAINER_REGISTRY).azurecr.io/orleans-repro-silo:latest"
az containerapp update --name web --resource-group $env:RESOURCE_GROUP --image "$($env:CONTAINER_REGISTRY).azurecr.io/orleans-repro-client:latest"