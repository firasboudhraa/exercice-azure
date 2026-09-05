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

Run against AWS:

```powershell
$env:TARGET_URL="http://YOUR_LOAD_BALANCER_DNS"
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
- ECS desired task count and running task count before and during load.
- CloudWatch logs for backend errors or slow requests.
- Any bottleneck observed in `/metrics`.

Recommended manual scaling commands for the exercise:

```powershell
aws ecs update-service `
  --cluster opsboard-cluster `
  --service opsboard-api `
  --desired-count 2 `
  --region eu-west-3

aws ecs update-service `
  --cluster opsboard-cluster `
  --service opsboard `
  --desired-count 2 `
  --region eu-west-3
```

Recommended status checks:

```powershell
aws ecs describe-services `
  --cluster opsboard-cluster `
  --services opsboard-api opsboard `
  --region eu-west-3 `
  --query "services[].{service:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount}"
```

The deployed stack also includes target-tracking autoscaling policies for both ECS services. PostgreSQL is shared persistence, so multiple backend tasks can safely serve traffic concurrently.
