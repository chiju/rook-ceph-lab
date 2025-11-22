# Integration Steps - IAM Identity Center (Terraform Automated!)

## What Was Created

✅ **Terraform Module**: `terraform/modules/iam-identity-center/`  
✅ **ArgoCD App**: `apps/rbac-setup/`  
✅ **ArgoCD Manifest**: `argocd-apps/rbac-setup.yaml`  

---

## Complete Setup Flow

### **Step 1: Bootstrap S3 Backend** (if not done)
```bash
./scripts/bootstrap-backend.sh
```

### **Step 2: Setup OIDC** (if not done)
```bash
./scripts/setup-oidc-access.sh
gh secret set GIT_USERNAME -b "your-github-username"
gh secret set ARGOCD_GITHUB_TOKEN -b "your-github-pat"
```

### **Step 3: Enable IAM Identity Center** (Manual - One Time)
```
1. Go to: https://console.aws.amazon.com/singlesignon
2. Click "Enable"
3. Choose "Identity Center directory" as identity source
```

### **Step 4: Add Email Secrets**
```bash
gh secret set USER_EMAIL_PREFIX -b "your-email-prefix"
gh secret set USER_EMAIL_DOMAIN -b "gmail.com"
```

Example: For `chijuar@gmail.com`, use:
- `USER_EMAIL_PREFIX`: `chijuar`
- `USER_EMAIL_DOMAIN`: `gmail.com`

Users will be created as:
- `chijuar+alice@gmail.com`
- `chijuar+bob@gmail.com`
- `chijuar+charlie@gmail.com`
- `chijuar+diana@gmail.com`

### **Step 5: Deploy**
```bash
git push origin main
```

**Terraform will automatically:**
- ✅ Create 4 users
- ✅ Create 4 permission sets
- ✅ Create account assignments (creates SSO roles)
- ✅ Create EKS Access Entries
- ✅ ArgoCD deploys RBAC

---

## Step 6: Test SSO Access

### **Configure SSO**
```bash
aws configure sso
# SSO start URL: https://d-xxxxx.awsapps.com/start
# SSO region: eu-central-1
# Account: (your account)
# Role: PlatformAdmin
# Profile name: alice-admin
```

### **Login**
```bash
aws sso login --profile alice-admin
```

### **Access EKS**
```bash
aws eks update-kubeconfig --name eks-gitops-lab --profile alice-admin --region eu-central-1
kubectl get nodes
```

---

## Benefits of Terraform Approach

### ✅ **Better than Bash Scripts:**
- Fully automated
- Idempotent (run multiple times safely)
- State management
- Handles dependencies automatically
- Production-ready

### ✅ **What Terraform Manages:**
- Users
- Permission sets
- Account assignments
- EKS Access Entries
- Everything in one apply!

---

## Cleanup

```bash
# Terraform destroy handles everything
gh workflow run terraform-destroy.yml -f confirm=destroy

# Or use cleanup script
./scripts/cleanup-all.sh
```

Terraform will automatically delete:
- EKS Access Entries
- Account assignments
- Permission sets
- Users

---

## Summary

**Setup Steps:**
1. ✅ Enable Identity Center (one-time, 30 seconds)
2. ✅ Add email secrets
3. ✅ Push to deploy

**Everything else is automated by Terraform!** 🚀

