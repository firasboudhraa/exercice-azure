# Azure And GitHub Actions Deployment

## One-Time Azure Infrastructure

Run this once from a normal terminal with Azure CLI access:

```powershell
cd C:\Users\firas\Documents\ChatGPT\exercice
az login
.\infra\azure\deploy.ps1 -AppName opsboard -Location westeurope -AdminToken "replace-with-strong-token"
```

The script prints:

- Public app URL.
- Resource group.
- Azure Container Registry name.
- Frontend Container App name.
- Backend Container App name.
- PostgreSQL server name.
- Database name.

Save those values for GitHub repository variables.

## GitHub Repository Variables

Create these repository variables:

```text
AZURE_RESOURCE_GROUP
AZURE_ACR_NAME
AZURE_FRONTEND_CONTAINER_APP_NAME
AZURE_BACKEND_CONTAINER_APP_NAME
```

Example with GitHub CLI:

```powershell
gh variable set AZURE_RESOURCE_GROUP --body "rg-opsboard"
gh variable set AZURE_ACR_NAME --body "youracrname"
gh variable set AZURE_FRONTEND_CONTAINER_APP_NAME --body "opsboard"
gh variable set AZURE_BACKEND_CONTAINER_APP_NAME --body "opsboard-api"
```

## GitHub Repository Secrets

Create these repository secrets for Azure OIDC login:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

Example:

```powershell
gh secret set AZURE_CLIENT_ID --body "..."
gh secret set AZURE_TENANT_ID --body "..."
gh secret set AZURE_SUBSCRIPTION_ID --body "..."
```

## How To Get The Azure Values

The workflow uses OpenID Connect, so you do not need to create or store an Azure client secret. You need a Microsoft Entra application, a federated credential for this GitHub repository, and role assignments.

Set these values in your terminal:

```powershell
$owner = "YOUR_GITHUB_USERNAME_OR_ORG"
$repo = "YOUR_REPOSITORY_NAME"
$resourceGroup = "rg-opsboard"
$acrName = "THE_ACR_NAME_PRINTED_BY_DEPLOY_SCRIPT"
```

Get your subscription and tenant:

```powershell
$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv
```

Create the Microsoft Entra application used by GitHub Actions:

```powershell
$clientId = az ad app create --display-name "opsboard-github-actions" --query appId -o tsv
az ad sp create --id $clientId
```

Allow that identity to deploy into the resource group:

```powershell
$scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
az role assignment create --assignee $clientId --role Contributor --scope $scope
```

Allow that identity to push Docker images to Azure Container Registry:

```powershell
$acrId = az acr show --name $acrName --resource-group $resourceGroup --query id -o tsv
az role assignment create --assignee $clientId --role AcrPush --scope $acrId
```

Create the federated credential for automatic deployments from `main`:

```powershell
$credential = @{
  name = "opsboard-main"
  issuer = "https://token.actions.githubusercontent.com"
  subject = "repo:{0}/{1}:ref:refs/heads/main" -f $owner, $repo
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json

$credential | Out-File -Encoding utf8 .\github-oidc.json
az ad app federated-credential create --id $clientId --parameters .\github-oidc.json
Remove-Item .\github-oidc.json
```

Now add GitHub secrets:

```powershell
gh secret set AZURE_CLIENT_ID --body $clientId
gh secret set AZURE_TENANT_ID --body $tenantId
gh secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId
```

Add GitHub variables:

```powershell
gh variable set AZURE_RESOURCE_GROUP --body $resourceGroup
gh variable set AZURE_ACR_NAME --body $acrName
gh variable set AZURE_FRONTEND_CONTAINER_APP_NAME --body "opsboard"
gh variable set AZURE_BACKEND_CONTAINER_APP_NAME --body "opsboard-api"
```

After this, every push to `main` triggers the CI/CD pipeline and deploys the frontend and backend images automatically.

## Pipeline Behavior

Single CI/CD workflow:

```text
.github/workflows/ci-cd.yml
```

Runs on pull requests and pushes to `main`. It installs dependencies, lints, tests, audits dependencies, validates Docker Compose, and builds the frontend and backend Docker images.

Automatic deployment:

```text
.github/workflows/ci-cd.yml
```

Runs after validation on every push to `main`, and can also be started manually from GitHub Actions. It builds frontend and backend Docker images, pushes them to Azure Container Registry, deploys both images to Azure Container Apps, then calls `/healthz` and `/readyz` on the public frontend HTTPS URL.

Day-to-day flow:

```powershell
git add .
git commit -m "feat: update opsboard"
git push origin main
```

After the push, GitHub Actions automatically runs the pipeline and deploys the new version to Azure.

## Final Submission Evidence

Include these in the exercise submission:

- GitHub repository URL.
- Azure public URL.
- Screenshot or pasted output from the successful GitHub Actions CI run.
- Screenshot or pasted output from the successful GitHub Actions deployment run.
- Load-test result from `npm run load:local`.
