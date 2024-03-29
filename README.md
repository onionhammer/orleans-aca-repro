## The issue:
[./infra/provision.bicep](./infra/provision.bicep#L62) (line 62) specifies use of workload profiles

- If the workload profiles area is there, the app fails to function
- If the workload profiles are absent, the app functions fine.

## Steps

1. Setup winget

```ps1
winget install -e --id Microsoft.AzureCLI
# Restart the terminal session after installing the az CLI before running the next command
az login
```

2. Select subscription

```ps1
az account list --output table
az account set --subscription your-subscription-id-pasted-here
```

3. Setup CLI

```ps1
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry
```

4. Update deploy.ps1 environment variables

5. Run deploy.ps1 to deploy the app with workload profiles enabled

```ps1
./deploy.ps1
```

6. Open [./infra/provision.bicep](./infra/provision.bicep#L62) and comment out the workload profiles section

7. Open a new terminal session, and run deploy.ps1 with a different '-SolutionName' parameter to deploy the app with workload profiles disabled

```ps1
./deploy.ps1 -SolutionName "orleans-ac2"
```

## More info:

https://learn.microsoft.com/en-us/dotnet/aspire/deployment/azure/aca-deployment?tabs=visual-studio%2Cinstall-az-windows%2Cpowershell&pivots=azure-bicep