#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-opsboard}"
LOCATION="${2:-westeurope}"
FRONTEND_APP_NAME="${FRONTEND_APP_NAME:-$APP_NAME}"
BACKEND_APP_NAME="${BACKEND_APP_NAME:-$APP_NAME-api}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-$APP_NAME}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
DATABASE_NAME="${DATABASE_NAME:-opsboard}"
DATABASE_ADMIN_USER="${DATABASE_ADMIN_USER:-opsboardadmin}"
DATABASE_ADMIN_PASSWORD="${DATABASE_ADMIN_PASSWORD:-}"

NORMALIZED="$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
SUFFIX="$((10000 + RANDOM % 89999))"
ACR_NAME="${NORMALIZED}${SUFFIX}"
ENVIRONMENT_NAME="${APP_NAME}-env"
IDENTITY_NAME="${APP_NAME}-acr-pull"
BACKEND_IMAGE_NAME="opsboard-backend"
FRONTEND_IMAGE_NAME="opsboard-frontend"
POSTGRES_NAME="${NORMALIZED}-pg-${SUFFIX}"

if [ -z "$DATABASE_ADMIN_PASSWORD" ]; then
  DATABASE_ADMIN_PASSWORD="$(node -e "console.log(require('node:crypto').randomBytes(18).toString('base64url') + '!1Aa')")"
fi

az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights

az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --admin-enabled false
az postgres flexible-server create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$POSTGRES_NAME" \
  --location "$LOCATION" \
  --admin-user "$DATABASE_ADMIN_USER" \
  --admin-password "$DATABASE_ADMIN_PASSWORD" \
  --database-name "$DATABASE_NAME" \
  --version 16 \
  --tier Burstable \
  --sku-name Standard_B1ms \
  --storage-size 32 \
  --backup-retention 7 \
  --public-access 0.0.0.0

az containerapp env create --name "$ENVIRONMENT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION"

az acr build --registry "$ACR_NAME" --image "$BACKEND_IMAGE_NAME:$IMAGE_TAG" --file backend/Dockerfile .
az acr build --registry "$ACR_NAME" --image "$FRONTEND_IMAGE_NAME:$IMAGE_TAG" --file frontend/Dockerfile .

IDENTITY_JSON="$(az identity create --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP")"
IDENTITY_ID="$(printf '%s' "$IDENTITY_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).id))")"
PRINCIPAL_ID="$(printf '%s' "$IDENTITY_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).principalId))")"
ACR_ID="$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID"

LOGIN_SERVER="$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)"
BACKEND_IMAGE="$LOGIN_SERVER/$BACKEND_IMAGE_NAME:$IMAGE_TAG"
FRONTEND_IMAGE="$LOGIN_SERVER/$FRONTEND_IMAGE_NAME:$IMAGE_TAG"
DATABASE_URL="postgresql://$DATABASE_ADMIN_USER:$DATABASE_ADMIN_PASSWORD@$POSTGRES_NAME.postgres.database.azure.com:5432/$DATABASE_NAME?sslmode=require"

BACKEND_SECRETS=("database-url=$DATABASE_URL")
BACKEND_ENV_VARS=("NODE_ENV=production" "APP_VERSION=$IMAGE_TAG" "DATABASE_URL=secretref:database-url" "DATABASE_SSL=true")
if [ -n "$ADMIN_TOKEN" ]; then
  BACKEND_SECRETS+=("admin-token=$ADMIN_TOKEN")
  BACKEND_ENV_VARS+=("ADMIN_TOKEN=secretref:admin-token")
fi

az containerapp create \
  --name "$BACKEND_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --user-assigned "$IDENTITY_ID" \
  --registry-identity "$IDENTITY_ID" \
  --registry-server "$LOGIN_SERVER" \
  --image "$BACKEND_IMAGE" \
  --ingress internal \
  --target-port 8080 \
  --min-replicas 1 \
  --max-replicas 5 \
  --scale-rule-name http-scale \
  --scale-rule-http-concurrency 50 \
  --secrets "${BACKEND_SECRETS[@]}" \
  --env-vars "${BACKEND_ENV_VARS[@]}"

BACKEND_FQDN="$(az containerapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)"

az containerapp create \
  --name "$FRONTEND_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --user-assigned "$IDENTITY_ID" \
  --registry-identity "$IDENTITY_ID" \
  --registry-server "$LOGIN_SERVER" \
  --image "$FRONTEND_IMAGE" \
  --ingress external \
  --target-port 8080 \
  --min-replicas 1 \
  --max-replicas 5 \
  --scale-rule-name http-scale \
  --scale-rule-http-concurrency 50 \
  --env-vars "BACKEND_ORIGIN=https://$BACKEND_FQDN" "PORT=8080" "APP_VERSION=$IMAGE_TAG"

FRONTEND_FQDN="$(az containerapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)"
printf 'Application URL: https://%s\n' "$FRONTEND_FQDN"
printf 'Frontend app: %s\n' "$FRONTEND_APP_NAME"
printf 'Backend app: %s\n' "$BACKEND_APP_NAME"
printf 'Resource group: %s\n' "$RESOURCE_GROUP"
printf 'ACR name: %s\n' "$ACR_NAME"
printf 'PostgreSQL server: %s.postgres.database.azure.com\n' "$POSTGRES_NAME"
printf 'Database: %s\n' "$DATABASE_NAME"
printf '\nGitHub variables for automatic CI/CD:\n'
printf 'AZURE_RESOURCE_GROUP=%s\n' "$RESOURCE_GROUP"
printf 'AZURE_ACR_NAME=%s\n' "$ACR_NAME"
printf 'AZURE_FRONTEND_CONTAINER_APP_NAME=%s\n' "$FRONTEND_APP_NAME"
printf 'AZURE_BACKEND_CONTAINER_APP_NAME=%s\n' "$BACKEND_APP_NAME"
