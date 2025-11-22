# Setup Scripts

Automated scripts for EKS GitOps Lab setup and teardown.

## 🚀 Quick Start (3 Steps)

### 1. Bootstrap Backend

```bash
./scripts/bootstrap-backend.sh
```

Creates:
- S3 bucket for Terraform state (with versioning & encryption)
- Uses native S3 locking (no DynamoDB needed)
- Auto-updates `terraform/backend.tf`

### 2. Setup OIDC Access

```bash
./scripts/setup-oidc-access.sh
```

Creates:
- GitHub OIDC provider in AWS
- IAM role for GitHub Actions
- Auto-adds 3 GitHub secrets

### 3. Add Manual Secrets

```bash
gh secret set GIT_USERNAME -b "your-github-username"
gh secret set ARGOCD_GITHUB_TOKEN -b "your-github-pat"
```

Then push to deploy:
```bash
git push origin main
```

## 🧹 Cleanup

```bash
./scripts/cleanup-all.sh
```

Deletes:
- IAM role
- S3 bucket and all objects
- GitHub secrets
- Local Terraform files

## 📝 Scripts

| Script | Purpose |
|--------|---------|
| `bootstrap-backend.sh` | Create S3 backend for Terraform state |
| `setup-oidc-access.sh` | Configure AWS OIDC for GitHub Actions |
| `cleanup-all.sh` | Complete teardown of all resources |
