# Exercise Delivery Checklist

This checklist maps the exercise requirements to concrete files and behavior in the repository.

## Objective

Build and deliver a small production-ready application.

Evidence:

- App purpose and architecture: `README.md`, `docs/architecture.md`
- Runnable UI: `frontend/index.html`, `frontend/app.js`, `frontend/styles.css`
- Backend API: `backend/src/app.js`, `backend/src/server.js`
- Database persistence: `backend/src/stores/postgres-store.js`, `backend/migrations/001_create_incidents.sql`

## Expected Deliverable

Provide a Git repository containing everything needed to run, build, deploy, and understand the app.

Evidence:

- Local run commands: `README.md`
- Docker runtime: `frontend/Dockerfile`, `backend/Dockerfile`, `docker-compose.yml`
- AWS deployment scripts: `infra/aws/deploy.ps1`, `infra/aws/create-github-oidc-role.ps1`, `infra/aws/cloudformation.yml`
- CI/CD workflow: `.github/workflows/ci-cd.yml`
- API spec: `docs/api/openapi.yaml`
- Database schema: `docs/database-schema.sql`, `backend/migrations/001_create_incidents.sql`

## User Interface

Requirement: the app must include a user interface.

Implemented:

- Incident dashboard with total, open, in-progress, and active critical counters.
- Create incident form.
- Search and filter controls.
- Status transition buttons.

## Backend Service

Requirement: the app must include a backend service.

Implemented:

- `GET /api/incidents`
- `POST /api/incidents`
- `PATCH /api/incidents/{id}/status`
- `GET /api/stats`
- `GET /healthz`
- `GET /readyz`
- `GET /metrics`

## Database

Requirement from our chosen solution: use a real database, not static information.

Implemented:

- Local full-stack run uses PostgreSQL via Docker Compose.
- AWS deployment provisions Amazon RDS for PostgreSQL.
- `DATABASE_URL` selects PostgreSQL storage.
- File storage exists only for tests and emergency local fallback.

## Fully Containerized Application

Requirement: app must be containerized.

Evidence:

- `frontend/Dockerfile` builds the Nginx frontend image.
- `backend/Dockerfile` builds the Node.js API image.
- `docker-compose.yml` runs frontend, backend, and PostgreSQL together.
- Backend container runs as a non-root user.
- Frontend and backend expose port `8080`.
- Frontend and backend have health checks.

## Automated CI/CD Pipeline

Requirement: automated CI/CD pipeline, such as GitHub Actions.

Evidence:

- `.github/workflows/ci-cd.yml` validation job
  - Installs dependencies.
  - Runs lint.
  - Runs automated tests.
  - Runs dependency audit.
  - Validates Docker Compose.
  - Builds frontend and backend Docker images.
- `.github/workflows/ci-cd.yml` deployment job
  - Runs automatically on every push to `main`.
  - Authenticates to AWS with GitHub OIDC.
  - Builds and pushes frontend and backend images to Amazon ECR.
  - Registers new ECS task definition revisions.
  - Updates frontend and backend ECS services.
  - Verifies public `/healthz` and `/readyz`.

## Cloud Deployment

Requirement: deployment to AWS, Azure, or equivalent.

Implemented on AWS:

- Amazon ECR for Docker images.
- ECS Fargate for the public frontend runtime.
- ECS Fargate for the backend API runtime.
- Application Load Balancer for public access and path routing.
- Amazon RDS for PostgreSQL for persistence.
- AWS Secrets Manager for runtime secrets.
- CloudWatch Logs for runtime logs.

## Public Access

Requirement: public access to the running application.

Evidence:

- Application Load Balancer is internet-facing.
- Frontend service receives page requests.
- Backend service receives `/api/*`, `/healthz`, `/readyz`, `/metrics`, and `/openapi.yaml`.
- Deployment script prints the public URL.
- GitHub Actions deployment summary prints the public URL.

## Reliability Under Failure

Implemented:

- `/healthz` liveness endpoint.
- `/readyz` readiness endpoint checks database connectivity.
- Docker healthcheck.
- ECS service health checks through the load balancer.
- Rolling ECS deployments.
- Graceful shutdown on `SIGINT` and `SIGTERM`.
- Server-side validation and consistent error responses.

## Visibility Into Behavior

Implemented:

- Structured JSON request logs.
- Request ID on each response.
- Prometheus-style `/metrics` endpoint.
- AWS runtime logs through CloudWatch Logs.

## Security

Implemented:

- Secrets passed through environment variables and AWS Secrets Manager.
- `ADMIN_TOKEN` protects write endpoints when configured.
- RDS is private and only reachable from the backend security group.
- Security headers: CSP, frame protection, MIME sniffing protection, referrer policy, permissions policy.
- Input validation on API writes and filters.
- `npm audit --audit-level=high` in CI.
- GitHub Actions uses OIDC instead of long-lived AWS access keys.

## Scalability And Load

Implemented:

- Stateless frontend and backend containers.
- PostgreSQL shared persistence for multiple backend tasks.
- ECS services can scale from 1 to 4 tasks.
- Target-tracking autoscaling policies.
- Load smoke script: `backend/load/smoke-load.js`.
- Load-test notes: `docs/load-test.md`.

## Documentation

Requirement: document local run, deployment, and key decisions.

Evidence:

- `README.md`: run, test, Docker, AWS, CI/CD, security, known limits.
- `docs/architecture.md`: architecture, flows, non-functional targets.
- `docs/deployment.md`: AWS deployment and GitHub secrets/variables.
- `docs/load-test.md`: load simulation commands and expected evidence.
- `docs/exercise-checklist.md`: this requirement-to-evidence checklist.

## Recommended Commit Story

Use small commits because the exercise says commit history matters:

1. `chore: initialize opsboard project`
2. `feat: add incident API and postgres storage`
3. `feat: add dashboard UI and incident workflow`
4. `test: add validation api and smoke coverage`
5. `build: add docker compose and production images`
6. `ci: add github actions checks and aws deployment`
7. `docs: add architecture deployment and load-test notes`
