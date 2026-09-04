param(
  [string]$AppName = "opsboard",
  [string]$FrontendAppName = "",
  [string]$BackendAppName = "",
  [string]$Location = "westeurope",
  [string]$ResourceGroup = "",
  [string]$ImageTag = "latest",
  [string]$AdminToken = "",
  [string]$DatabaseName = "opsboard",
  [string]$DatabaseAdminUser = "opsboardadmin",
  [string]$DatabaseAdminPassword = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
  $ResourceGroup = "rg-$AppName"
}
if ([string]::IsNullOrWhiteSpace($FrontendAppName)) {
  $FrontendAppName = $AppName
}
if ([string]::IsNullOrWhiteSpace($BackendAppName)) {
  $BackendAppName = "$AppName-api"
}

$normalized = ($AppName.ToLower() -replace '[^a-z0-9]', '')
$suffix = (Get-Random -Minimum 10000 -Maximum 99999)
$AcrName = "$normalized$suffix"
$EnvironmentName = "$AppName-env"
$IdentityName = "$AppName-acr-pull"
$BackendImageName = "opsboard-backend"
$FrontendImageName = "opsboard-frontend"
$PostgresName = "$normalized-pg-$suffix"

if ([string]::IsNullOrWhiteSpace($DatabaseAdminPassword)) {
  $DatabaseAdminPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object {[char]$_})
  $DatabaseAdminPassword = "$DatabaseAdminPassword!1Aa"
}

az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights

az group create --name $ResourceGroup --location $Location
az acr create --resource-group $ResourceGroup --name $AcrName --sku Basic --admin-enabled false
az postgres flexible-server create `
  --resource-group $ResourceGroup `
  --name $PostgresName `
  --location $Location `
  --admin-user $DatabaseAdminUser `
  --admin-password $DatabaseAdminPassword `
  --database-name $DatabaseName `
  --version 16 `
  --tier Burstable `
  --sku-name Standard_B1ms `
  --storage-size 32 `
  --backup-retention 7 `
  --public-access 0.0.0.0

az containerapp env create --name $EnvironmentName --resource-group $ResourceGroup --location $Location

az acr build --registry $AcrName --image "$BackendImageName`:$ImageTag" --file backend/Dockerfile .
az acr build --registry $AcrName --image "$FrontendImageName`:$ImageTag" --file frontend/Dockerfile .

$identityJson = az identity create --name $IdentityName --resource-group $ResourceGroup | ConvertFrom-Json
$identityId = $identityJson.id
$principalId = $identityJson.principalId
$acrId = az acr show --name $AcrName --resource-group $ResourceGroup --query id -o tsv

az role assignment create `
  --assignee-object-id $principalId `
  --assignee-principal-type ServicePrincipal `
  --role AcrPull `
  --scope $acrId

$loginServer = az acr show --name $AcrName --resource-group $ResourceGroup --query loginServer -o tsv
$backendImage = "$loginServer/$BackendImageName`:$ImageTag"
$frontendImage = "$loginServer/$FrontendImageName`:$ImageTag"
$databaseUrl = "postgresql://$DatabaseAdminUser`:$DatabaseAdminPassword@$PostgresName.postgres.database.azure.com:5432/$DatabaseName`?sslmode=require"

$backendSecrets = @("database-url=$databaseUrl")
$backendEnvVars = @("NODE_ENV=production", "APP_VERSION=$ImageTag", "DATABASE_URL=secretref:database-url", "DATABASE_SSL=true")
if (-not [string]::IsNullOrWhiteSpace($AdminToken)) {
  $backendSecrets += "admin-token=$AdminToken"
  $backendEnvVars += "ADMIN_TOKEN=secretref:admin-token"
}

az containerapp create `
  --name $BackendAppName `
  --resource-group $ResourceGroup `
  --environment $EnvironmentName `
  --user-assigned $identityId `
  --registry-identity $identityId `
  --registry-server $loginServer `
  --image $backendImage `
  --ingress internal `
  --target-port 8080 `
  --min-replicas 1 `
  --max-replicas 5 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 50 `
  --secrets $backendSecrets `
  --env-vars $backendEnvVars

$backendFqdn = az containerapp show --name $BackendAppName --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn -o tsv

az containerapp create `
  --name $FrontendAppName `
  --resource-group $ResourceGroup `
  --environment $EnvironmentName `
  --user-assigned $identityId `
  --registry-identity $identityId `
  --registry-server $loginServer `
  --image $frontendImage `
  --ingress external `
  --target-port 8080 `
  --min-replicas 1 `
  --max-replicas 5 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 50 `
  --env-vars "BACKEND_ORIGIN=https://$backendFqdn" "PORT=8080" "APP_VERSION=$ImageTag"

$frontendFqdn = az containerapp show --name $FrontendAppName --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn -o tsv
Write-Host "Application URL: https://$frontendFqdn"
Write-Host "Frontend app: $FrontendAppName"
Write-Host "Backend app: $BackendAppName"
Write-Host "Resource group: $ResourceGroup"
Write-Host "ACR name: $AcrName"
Write-Host "PostgreSQL server: $PostgresName.postgres.database.azure.com"
Write-Host "Database: $DatabaseName"
Write-Host ""
Write-Host "GitHub variables for automatic CI/CD:"
Write-Host "AZURE_RESOURCE_GROUP=$ResourceGroup"
Write-Host "AZURE_ACR_NAME=$AcrName"
Write-Host "AZURE_FRONTEND_CONTAINER_APP_NAME=$FrontendAppName"
Write-Host "AZURE_BACKEND_CONTAINER_APP_NAME=$BackendAppName"
