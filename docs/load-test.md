# Load And Scaling Plan

Run locally against the full Docker/PostgreSQL stack:

```powershell
docker compose up --build
```

Then run:

```powershell
$env:TARGET_URL="http://127.0.0.1:8080"
$env:DURATION_SECONDS="30"
$env:CONCURRENCY="25"
$env:ADMIN_TOKEN="change-me-local"
npm run load:local
```

Run against Azure:

```powershell
$env:TARGET_URL="https://YOUR_CONTAINER_APP_URL"
$env:DURATION_SECONDS="60"
$env:CONCURRENCY="50"
$env:WRITE_RATIO="0.02"
$env:ADMIN_TOKEN="YOUR_TOKEN_IF_ENABLED"
npm run load:local
```

What to capture in the final README or submission notes:

- Requests per second.
- Failed request count.
- p50 and p95 latency.
- Azure Container Apps replica count before and during load.
- Any bottleneck observed in logs or metrics.

Recommended scaling rule for the public frontend app:

```powershell
az containerapp update `
  --name opsboard `
  --resource-group rg-opsboard `
  --min-replicas 1 `
  --max-replicas 5 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 50
```

Azure Container Apps supports HTTP scaling based on concurrent requests, so both app containers use simple HTTP concurrency thresholds.

Recommended scaling rule for the internal backend API app:

```powershell
az containerapp update `
  --name opsboard-api `
  --resource-group rg-opsboard `
  --min-replicas 1 `
  --max-replicas 5 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 50
```

The frontend uses public HTTP ingress. The backend uses internal HTTP ingress and scales independently.
