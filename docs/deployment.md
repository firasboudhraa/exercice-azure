# AWS And GitHub Actions Deployment

## AWS Login

Install and configure AWS CLI, then verify the account:

```powershell
aws configure
aws sts get-caller-identity
```

If your AWS account uses IAM Identity Center, use:

```powershell
aws configure sso
aws sso login
aws sts get-caller-identity
```

Use an IAM user or role allowed to create ECR repositories, CloudFormation stacks, ECS services, RDS databases, Secrets Manager secrets, load balancers, security groups, and IAM roles.

## One-Time AWS Infrastructure

Run this once from PowerShell with AWS CLI and Docker available:

```powershell
cd C:\Users\firas\Documents\ChatGPT\exercice
aws sts get-caller-identity
.\infra\aws\deploy.ps1 -AppName opsboard -Region eu-west-3 -AdminToken "replace-with-strong-token"
```

The script prints:

- Public application URL.
- AWS region.
- CloudFormation stack name.
- Amazon ECR backend repository.
- Amazon ECR frontend repository.
- ECS cluster name.
- Backend ECS service name.
- Frontend ECS service name.
- Task definition families.

Save the printed values for GitHub repository variables.

If your AWS account has no default VPC, pass a VPC and at least two subnets manually:

```powershell
.\infra\aws\deploy.ps1 `
  -AppName opsboard `
  -Region eu-west-3 `
  -AdminToken "replace-with-strong-token" `
  -VpcId "vpc-xxxxxxxx" `
  -SubnetIds "subnet-aaaaaaa,subnet-bbbbbbb"
```

## Create The GitHub OIDC Role

The workflow uses GitHub OIDC, so you do not store long-lived AWS access keys in GitHub. Create the deploy role after the CloudFormation stack exists:

```powershell
.\infra\aws\create-github-oidc-role.ps1 `
  -AppName opsboard `
  -Region eu-west-3 `
  -StackName opsboard-prod `
  -GitHubOwner firasboudhraa `
  -GitHubRepo exercice-azure
```

Use the exact GitHub repository name. If you rename the repository to `exercice-aws`, change `-GitHubRepo exercice-azure` to `-GitHubRepo exercice-aws`.

The script prints:

```text
AWS_ROLE_TO_ASSUME=arn:aws:iam::<account-id>:role/opsboard-github-actions
```

Save that value as a GitHub Actions secret.

If AWS refuses the IAM commands, use an administrator IAM user/role, or ask the AWS account administrator to run the script. GitHub Actions needs permission to push images to ECR, register ECS task definitions, update ECS services, pass the ECS task roles, and read the CloudFormation stack output.

## GitHub Repository Secret

Create this repository secret:

```text
AWS_ROLE_TO_ASSUME
```

Example with GitHub CLI:

```powershell
gh secret set AWS_ROLE_TO_ASSUME --body "arn:aws:iam::<account-id>:role/opsboard-github-actions"
```

GitHub web path:

```text
GitHub repo -> Settings -> Secrets and variables -> Actions -> Secrets -> New repository secret
```

## GitHub Repository Variables

Create these repository variables:

```text
AWS_REGION
AWS_STACK_NAME
AWS_ECR_BACKEND_REPOSITORY
AWS_ECR_FRONTEND_REPOSITORY
AWS_ECS_CLUSTER
AWS_ECS_BACKEND_SERVICE
AWS_ECS_FRONTEND_SERVICE
AWS_BACKEND_TASK_FAMILY
AWS_FRONTEND_TASK_FAMILY
```

Expected values for the default deployment:

```text
AWS_REGION=eu-west-3
AWS_STACK_NAME=opsboard-prod
AWS_ECR_BACKEND_REPOSITORY=opsboard-backend
AWS_ECR_FRONTEND_REPOSITORY=opsboard-frontend
AWS_ECS_CLUSTER=opsboard-cluster
AWS_ECS_BACKEND_SERVICE=opsboard-api
AWS_ECS_FRONTEND_SERVICE=opsboard
AWS_BACKEND_TASK_FAMILY=opsboard-api
AWS_FRONTEND_TASK_FAMILY=opsboard-frontend
```

Example with GitHub CLI:

```powershell
gh variable set AWS_REGION --body "eu-west-3"
gh variable set AWS_STACK_NAME --body "opsboard-prod"
gh variable set AWS_ECR_BACKEND_REPOSITORY --body "opsboard-backend"
gh variable set AWS_ECR_FRONTEND_REPOSITORY --body "opsboard-frontend"
gh variable set AWS_ECS_CLUSTER --body "opsboard-cluster"
gh variable set AWS_ECS_BACKEND_SERVICE --body "opsboard-api"
gh variable set AWS_ECS_FRONTEND_SERVICE --body "opsboard"
gh variable set AWS_BACKEND_TASK_FAMILY --body "opsboard-api"
gh variable set AWS_FRONTEND_TASK_FAMILY --body "opsboard-frontend"
```

GitHub web path:

```text
GitHub repo -> Settings -> Secrets and variables -> Actions -> Variables -> New repository variable
```

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

Runs after validation on every push to `main`, and can also be started manually from GitHub Actions. It builds frontend and backend Docker images, pushes them to Amazon ECR, registers new ECS task definition revisions, updates both ECS services, waits for stability, then calls `/healthz` and `/readyz` on the public load balancer URL.

Day-to-day flow:

```powershell
git add .
git commit -m "feat: update opsboard"
git push origin main
```

After the push, GitHub Actions automatically runs the pipeline and deploys the new version to AWS.

## Runtime Secrets

Do not put database passwords or admin tokens in source files.

The initial AWS deployment script passes:

- `DATABASE_URL` to AWS Secrets Manager.
- `ADMIN_TOKEN` to AWS Secrets Manager.

The ECS backend task reads those secrets at runtime. GitHub Actions only updates container images and task definition revisions; it does not need the database password.

## Load Test Against AWS

After deployment:

```powershell
$env:TARGET_URL="http://YOUR_LOAD_BALANCER_DNS"
$env:DURATION_SECONDS="60"
$env:CONCURRENCY="50"
$env:WRITE_RATIO="0.02"
$env:ADMIN_TOKEN="YOUR_ADMIN_TOKEN"
npm run load:local
```

Record:

- Requests per second.
- Failed request count.
- p50 and p95 latency.
- ECS desired/running task count during the test.
- Any bottleneck seen in CloudWatch logs or metrics.

## Cleanup

To avoid ongoing AWS cost after the exercise:

```powershell
aws cloudformation delete-stack --stack-name opsboard-prod --region eu-west-3
aws cloudformation wait stack-delete-complete --stack-name opsboard-prod --region eu-west-3
aws ecr delete-repository --repository-name opsboard-backend --force --region eu-west-3
aws ecr delete-repository --repository-name opsboard-frontend --force --region eu-west-3
```

## Final Submission Evidence

Include these in the exercise submission:

- GitHub repository URL.
- AWS public URL.
- Screenshot or pasted output from the successful GitHub Actions CI run.
- Screenshot or pasted output from the successful GitHub Actions deployment run.
- Load-test result from `npm run load:local`.
