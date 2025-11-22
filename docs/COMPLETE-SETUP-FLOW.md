# Complete Setup Flow - From Scratch

## Your Current Architecture (100% Automated)

### Phase 1: Bootstrap (Manual - One Time)

```bash
# Step 1: Create S3 backend
./scripts/bootstrap-backend.sh
# Uses: AWS_PROFILE=oth_infra
# Creates: S3 bucket with random name
# Updates: terraform/backend.tf automatically

# Step 2: Setup OIDC for GitHub Actions
./scripts/setup-oidc-access.sh
# Uses: AWS_PROFILE=oth_infra
# Creates: OIDC provider + IAM role
# Adds: 3 GitHub secrets automatically
#   - AWS_ROLE_ARN
#   - AWS_ACCOUNT_ID
#   - GIT_REPO_URL

# Step 3: Add manual secrets
gh secret set GIT_USERNAME -b "chiju"
gh secret set ARGOCD_GITHUB_TOKEN -b "<your-pat>"
```

### Phase 2: Deploy (Fully Automated)

```bash
git push origin main
```

**GitHub Actions Workflow:**

```
1. Validate Job
   ├─ terraform fmt -check
   ├─ terraform init -backend=false
   └─ terraform validate

2. Security Job (parallel)
   └─ Checkov scan (soft-fail)

3. Plan Job
   ├─ Configure AWS (OIDC - no credentials!)
   ├─ terraform init (with S3 backend)
   ├─ terraform plan
   └─ Upload plan artifact

4. Apply Job (if changes detected)
   ├─ Download plan artifact
   ├─ terraform apply (with retry for EKS)
   ├─ Post-deployment tests
   │  ├─ kubectl wait for nodes
   │  └─ kubectl wait for ArgoCD
   └─ Trigger update-app-values workflow

5. Update App Values Job
   ├─ Get Terraform outputs
   ├─ Update Karpenter values.yaml
   ├─ Update EC2NodeClass
   ├─ Update Grafana ServiceAccount
   ├─ Commit changes [skip ci]
   └─ Push to main
```

### Phase 3: ArgoCD Takes Over (Automatic)

```
ArgoCD (installed by Terraform)
├─ Monitors: argocd-apps/ directory
├─ Syncs: Every 30 seconds
└─ Deploys:
   ├─ nginx (with KEDA)
   ├─ keda
   ├─ karpenter (with updated values)
   ├─ monitoring (with Grafana CloudWatch)
   ├─ loki
   └─ promtail
```

---

## For IAM SSO Simulation - What Changes?

### Nothing Changes in Bootstrap!

Bootstrap stays the same:
- ✅ S3 backend creation
- ✅ OIDC setup
- ✅ GitHub secrets

### Terraform Changes (Automated)

Add to `terraform/main.tf`:
```hcl
module "iam_sso_sim" {
  source = "./modules/iam-sso-sim"
  
  cluster_name = var.cluster_name
  aws_region   = var.aws_region
  
  depends_on = [module.eks]
}
```

Add to `terraform/outputs.tf`:
```hcl
output "iam_sso_setup_instructions" {
  value = module.iam_sso_sim.setup_instructions
}

output "iam_sso_aws_config" {
  value     = module.iam_sso_sim.aws_config_profiles
  sensitive = true
}

output "iam_sso_credentials" {
  value     = module.iam_sso_sim.user_credentials
  sensitive = true
}
```

### GitHub Actions Workflow (No Changes!)

Same workflow runs:
1. Validate → Security → Plan → Apply
2. Creates IAM users/roles automatically
3. Creates EKS Access Entries automatically
4. Update-app-values runs (no changes needed)

### ArgoCD Deploys RBAC (Automatic)

ArgoCD detects new app:
- `argocd-apps/rbac-setup.yaml` → Deploys `apps/rbac-setup/`
- Creates namespaces (dev, staging)
- Creates RBAC roles
- Creates resource quotas

---

## What's Automated vs Manual

### Automated (GitHub Actions)
✅ Terraform validation  
✅ Security scanning  
✅ IAM users creation  
✅ IAM roles creation  
✅ EKS Access Entries  
✅ EKS cluster deployment  
✅ ArgoCD installation  
✅ App values update  
✅ RBAC deployment (via ArgoCD)  

### Manual (One-Time Setup)
❌ Bootstrap S3 backend (once)  
❌ Setup OIDC (once)  
❌ Add 2 GitHub secrets (once)  

### Manual (After Deployment)
❌ Get Terraform outputs for credentials  
❌ Add AWS config to ~/.aws/config  
❌ Test with kubectl  

---

## Key Insights

### 1. No Credentials in GitHub Actions
```
GitHub Actions → OIDC → AWS IAM Role → Temporary credentials
```
**No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY stored!**

### 2. Your Local Access
```
export AWS_PROFILE=oth_infra
terraform output iam_sso_setup_instructions
```
**You use your profile, GitHub Actions uses OIDC**

### 3. Terraform Outputs in Workflow
```yaml
# In GitHub Actions logs, you'll see:
Outputs:

iam_sso_setup_instructions = <<EOT
╔═══════════════════════════════════════╗
║  IAM Identity Center Simulation       ║
╚═══════════════════════════════════════╝

📝 Next Steps:
...
EOT
```

### 4. ArgoCD Auto-Sync
```
Push to main → Terraform creates IAM
              ↓
ArgoCD sees argocd-apps/rbac-setup.yaml
              ↓
ArgoCD deploys apps/rbac-setup/
              ↓
Namespaces + RBAC created (30 seconds)
```

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ONE-TIME BOOTSTRAP                        │
│  (Manual - Uses AWS_PROFILE=oth_infra)                      │
├─────────────────────────────────────────────────────────────┤
│  1. ./scripts/bootstrap-backend.sh                          │
│     → Creates S3 bucket                                      │
│     → Updates terraform/backend.tf                           │
│                                                              │
│  2. ./scripts/setup-oidc-access.sh                          │
│     → Creates OIDC provider                                  │
│     → Creates IAM role for GitHub Actions                    │
│     → Adds 3 GitHub secrets                                  │
│                                                              │
│  3. gh secret set GIT_USERNAME                              │
│     gh secret set ARGOCD_GITHUB_TOKEN                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    PUSH TO MAIN                              │
│  (Fully Automated - GitHub Actions)                         │
├─────────────────────────────────────────────────────────────┤
│  GitHub Actions Workflow:                                    │
│  ├─ Validate Terraform                                       │
│  ├─ Security Scan (Checkov)                                  │
│  ├─ Plan (OIDC auth - no credentials!)                      │
│  ├─ Apply                                                    │
│  │  ├─ Creates VPC                                           │
│  │  ├─ Creates EKS cluster                                   │
│  │  ├─ Creates IAM users/roles (IAM SSO sim)               │
│  │  ├─ Creates EKS Access Entries                           │
│  │  └─ Installs ArgoCD                                       │
│  └─ Update App Values                                        │
│     ├─ Gets Terraform outputs                                │
│     ├─ Updates Karpenter config                              │
│     ├─ Updates Grafana config                                │
│     └─ Commits + pushes [skip ci]                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    ARGOCD AUTO-SYNC                          │
│  (Fully Automated - Every 30 seconds)                       │
├─────────────────────────────────────────────────────────────┤
│  ArgoCD monitors argocd-apps/ directory:                     │
│  ├─ nginx.yaml → Deploys apps/nginx/                        │
│  ├─ keda.yaml → Deploys apps/keda/                          │
│  ├─ karpenter.yaml → Deploys apps/karpenter/                │
│  ├─ monitoring.yaml → Deploys apps/kube-prometheus-stack/   │
│  ├─ loki.yaml → Deploys apps/loki/                          │
│  ├─ promtail.yaml → Deploys apps/promtail/                  │
│  └─ rbac-setup.yaml → Deploys apps/rbac-setup/ ← NEW!      │
│                                                              │
│  RBAC Setup Deploys:                                         │
│  ├─ Namespaces (dev, staging)                               │
│  ├─ Resource Quotas                                          │
│  ├─ Developer Roles (namespace-scoped)                       │
│  ├─ DevOps Roles (multi-namespace)                          │
│  └─ Viewer Roles (read-only)                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    GET CREDENTIALS                           │
│  (Manual - One Time)                                         │
├─────────────────────────────────────────────────────────────┤
│  Option A: From GitHub Actions Logs                          │
│  └─ Copy setup instructions from workflow output             │
│                                                              │
│  Option B: From Local Terraform                              │
│  └─ export AWS_PROFILE=oth_infra                            │
│     cd terraform                                             │
│     terraform output -raw iam_sso_aws_config >> ~/.aws/config│
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    TEST ACCESS                               │
│  (Manual - Validation)                                       │
├─────────────────────────────────────────────────────────────┤
│  # Alice (Platform Admin)                                    │
│  aws eks update-kubeconfig --name eks-lab \                 │
│    --profile eks-lab-alice-admin --region eu-central-1      │
│  kubectl get nodes  # ✅ Works                              │
│                                                              │
│  # Charlie (Developer)                                       │
│  aws eks update-kubeconfig --name eks-lab \                 │
│    --profile eks-lab-charlie-dev --region eu-central-1      │
│  kubectl get pods -n dev  # ✅ Works                        │
│  kubectl get nodes  # ❌ Forbidden (RBAC working!)          │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary

### What You Have Now
- ✅ 100% automated infrastructure deployment
- ✅ OIDC authentication (no stored credentials)
- ✅ GitOps with ArgoCD
- ✅ Auto-updating app configurations

### What IAM SSO Simulation Adds
- ✅ 4 simulated users (alice, bob, charlie, diana)
- ✅ 4 permission sets (PlatformAdmin, DevOpsEngineer, Developer, ReadOnly)
- ✅ EKS Access Entries (modern, not aws-auth)
- ✅ Namespace-scoped RBAC
- ✅ All deployed automatically via GitOps

### Manual Steps (Total: 5)
1. Bootstrap S3 backend (once)
2. Setup OIDC (once)
3. Add 2 GitHub secrets (once)
4. Get credentials from Terraform outputs (after deployment)
5. Test with kubectl (validation)

**Everything else is 100% automated!**
