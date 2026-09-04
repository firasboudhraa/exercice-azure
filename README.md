# OpsBoard

OpsBoard is a small production-style incident board built for the technical exercise. It includes a browser UI, backend API, PostgreSQL database, health/readiness probes, metrics, tests, Docker, CI/CD, and Azure Container Apps deployment scripts.

## Architecture

```mermaid
flowchart LR
  B[Browser] --> F[Frontend container: Nginx]
  F --> A[Backend container: Node.js API]
  A --> P[(PostgreSQL)]
  F --> M[Azure Monitor / Log Analytics]
  A --> M
  G[GitHub Actions] --> R[Azure Container Registry]
  R --> F
  R --> A
```

Docker Compose runs the complete stack: frontend container, backend container, and PostgreSQL. Azure deployment provisions Azure Database for PostgreSQL Flexible Server and injects the connection string into the backend through a Container Apps secret.

## Project Structure

```text
frontend/                 Browser UI
backend/                  API, database code, tests, load script
.github/workflows/ci-cd.yml  One GitHub Actions CI/CD pipeline
infra/azure/              Azure deployment scripts
docs/                     Architecture, API, deployment, checklist
frontend/Dockerfile       Frontend Nginx image
backend/Dockerfile        Backend Node.js API image
docker-compose.yml        Local app + PostgreSQL stack
```

## Features

- Incident dashboard with status and priority summaries.
- Create incident flow with backend validation.
- Status workflow: open, in progress, resolved.
- Search and filters.
- Frontend container proxies `/api`, `/healthz`, `/readyz`, `/metrics`, and `/openapi.yaml` to the backend.
- Backend exposes `/healthz`, `/readyz`, `/metrics`, and `/openapi.yaml`.
- PostgreSQL-backed persistence for the normal Docker/Azure path.
- Optional bearer-token protection for write endpoints through `ADMIN_TOKEN`.
- JSON structured logs to stdout for Azure Log Analytics.
- Dependency-free local tests and load smoke test.

## Tech Stack

- Runtime: Node.js 24.
- UI: browser-native HTML, CSS, and JavaScript.
- API: Node.js HTTP server.
- Data: PostgreSQL through `DATABASE_URL`; file mode exists only for tests and emergency local fallback.
- Containers: Docker.
- CI/CD: GitHub Actions.
- Cloud: Azure Container Apps, Azure Container Registry, Log Analytics, and Azure PostgreSQL Flexible Server.

## Local Commands

Install dependencies:

```powershell
npm install --prefix backend
```

Run the full local stack with PostgreSQL:

```powershell
docker compose up --build
```

Open:

```text
http://127.0.0.1:8080
```

Run the Node app directly against your own PostgreSQL:

```powershell
$env:DATABASE_URL="postgresql://opsboard:opsboard@127.0.0.1:5432/opsboard"
$env:DATABASE_SSL="false"
npm start
```

Developer fallback without PostgreSQL:

```powershell
$env:DATA_FILE=":memory:"
npm start
```

Run checks:

```powershell
npm run check
```

Run load smoke test:

```powershell
$env:TARGET_URL="http://127.0.0.1:8080"
npm run load:local
```

## API

OpenAPI spec: `docs/api/openapi.yaml`

Main endpoints:

- `GET /api/incidents`
- `POST /api/incidents`
- `PATCH /api/incidents/{id}/status`
- `GET /api/stats`
- `GET /healthz`
- `GET /readyz`
- `GET /metrics`

## Azure Deployment

Full deployment guide: `docs/deployment.md`

PowerShell:

```powershell
.\infra\azure\deploy.ps1 -AppName opsboard -Location westeurope
```

Bash:

```bash
./infra/azure/deploy.sh opsboard westeurope
```

The script creates:

- Resource group
- Azure Container Registry
- Azure Database for PostgreSQL Flexible Server
- Azure Container Apps environment
- User-assigned managed identity for ACR pull
- Internal backend Container App
- External frontend Container App
- Backend Container Apps secret for `DATABASE_URL`
- HTTP autoscale rule

The database is created with PostgreSQL 16, 7-day backup retention, and a small burstable SKU to keep the exercise cost reasonable. Increase the SKU and use private networking for stricter production environments.

## GitHub Actions

One workflow handles both CI and CD:

```text
.github/workflows/ci-cd.yml
```

The validation job runs on pull requests and main branch pushes. It installs backend dependencies, lints, tests, audits dependencies, validates Docker Compose, and builds both Docker images.

The deployment job runs automatically after validation on every push to `main`. It builds and pushes the frontend and backend images to Azure Container Registry, deploys both Azure Container Apps, then verifies `/healthz` and `/readyz` through the public frontend URL.

Automatic deployment flow:

```text
change code
commit
push to main
GitHub Actions validates the app
GitHub Actions deploys the new frontend and backend images to Azure
GitHub Actions smoke-tests the public URL
```

Deployment workflow expects these GitHub secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Deployment workflow expects these GitHub variables:

- `AZURE_RESOURCE_GROUP`
- `AZURE_ACR_NAME`
- `AZURE_FRONTEND_CONTAINER_APP_NAME`
- `AZURE_BACKEND_CONTAINER_APP_NAME`
 
The first infrastructure deployment should be done with `infra/azure/deploy.ps1` or `infra/azure/deploy.sh`. After that, the GitHub Actions deployment workflow updates the existing frontend and backend Container App revisions with each push to `main`.

## Exercise Checklist

The requirement-to-evidence checklist is in `docs/exercise-checklist.md`.

## Security

- Write APIs require `Authorization: Bearer <ADMIN_TOKEN>` when `ADMIN_TOKEN` is configured.
- Secrets are read only from environment variables or Azure Container Apps secrets.
- Input validation is enforced server-side.
- Security headers include CSP, frame protection, MIME sniffing protection, referrer policy, and permissions policy.
- No sensitive data is logged intentionally.
- Use `npm audit` in CI after dependencies are installed.

## Milestone Plan

1. Foundation: repo, folder structure, app objective, architecture docs, first commit.
2. Backend: API, validation, storage adapter, health/readiness, metrics.
3. Frontend: dashboard, create form, filters, status workflow.
4. Quality: unit tests, integration tests, e2e smoke test, linting.
5. Delivery: separate frontend/backend Dockerfiles, Compose, GitHub Actions, Azure scripts.
6. Evidence: deploy URL, load-test result, scaling notes, known limitations.

## Acceptance Criteria

- `npm run check` passes.
- `docker compose up --build` serves the UI on port 8080.
- `/healthz` and `/readyz` return 200.
- A new incident can be created and resolved from the UI.
- Azure Container App is reachable through a public HTTPS URL.
- Load-test notes document behavior under increased traffic.

## Known Limitations

- File storage is intentionally limited to tests and emergency fallback. The delivered stack uses PostgreSQL.
- Authentication is intentionally lightweight for the exercise. A production user-facing system should use Entra ID, OAuth/OIDC, or another managed identity provider.
