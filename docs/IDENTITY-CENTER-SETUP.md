# Identity Center Setup - Complete Automation

## What's Implemented

### Terraform Creates:
✅ Identity Center users (alice-dev, bob-devops, diana-viewer)  
✅ Permission sets (EKSDeveloper, EKSDevOps, EKSReadOnly)  
✅ User assignments (user → permission set)  
✅ Waits 3 minutes for SSO roles (async handling)  
✅ EKS access entries (SSO role → K8s group)  

### ArgoCD Deploys:
✅ Namespaces (dev, staging)  
✅ Roles (what each group can do)  
✅ RoleBindings (group → role)  

## Prerequisites

**Enable Identity Center first:**
```bash
# In AWS Console:
# IAM Identity Center → Enable

# Or via CLI:
aws sso-admin list-instances --region eu-central-1
# If empty, enable in console first
```

## Deployment Flow

```
1. terraform apply
   ├─ Creates VPC, EKS, ArgoCD
   ├─ Creates Identity Center users
   ├─ Creates permission sets
   ├─ Assigns users to permission sets
   ├─ Waits 3 minutes (SSO roles provisioning)
   └─ Creates EKS access entries
   
2. ArgoCD (automatic)
   └─ Deploys RBAC from Git

3. Check your emails
   └─ 3 invitation emails sent
```

## After Deployment

### 1. Check Emails
You'll receive 3 invitation emails:
- chijuar@gmail.com
- chijumel@gmail.com
- chijumelveettil@gmail.com

### 2. Set Passwords
Click each link and set passwords

### 3. Configure AWS CLI
```bash
aws configure sso
# SSO start URL: (from terraform output)
# SSO region: eu-central-1
# CLI default region: eu-central-1
# CLI profile name: alice-dev
```

Repeat for each user (bob-devops, diana-viewer)

### 4. Login and Test
```bash
# Alice (Developer)
aws sso login --profile alice-dev
aws eks update-kubeconfig --name eks-gitops-lab --profile alice-dev --region eu-central-1

kubectl get pods -n dev        # ✅ Works
kubectl delete pod xxx -n dev  # ✅ Works
kubectl get nodes              # ❌ Forbidden

# Bob (DevOps)
aws sso login --profile bob-devops
aws eks update-kubeconfig --name eks-gitops-lab --profile bob-devops --region eu-central-1

kubectl get pods -n dev        # ✅ Works
kubectl get pods -n staging    # ✅ Works
kubectl get nodes              # ✅ Works
kubectl delete node xxx        # ❌ Forbidden

# Diana (Viewer)
aws sso login --profile diana-viewer
aws eks update-kubeconfig --name eks-gitops-lab --profile diana-viewer --region eu-central-1

kubectl get pods -A            # ✅ Works
kubectl delete pod xxx         # ❌ Forbidden
kubectl get secrets -A         # ❌ Forbidden
```

## Adding New Users

### In terraform/main.tf:
```hcl
users = {
  # Existing users...
  
  # Add new user:
  emma-dev = {
    email        = "emma@example.com"
    given_name   = "Emma"
    family_name  = "Developer"
    display_name = "Emma Developer"
  }
}

user_assignments = {
  # Existing assignments...
  
  # Add assignment:
  emma-to-developer = {
    user           = "emma-dev"
    permission_set = "EKSDeveloper"
  }
}
```

Then:
```bash
git add .
git commit -m "Add emma to developers"
git push
# GitHub Actions runs terraform apply
# Emma gets invitation email
```

## Architecture

```
┌─────────────────────────────────────────────┐
│ Identity Center (AWS)                       │
│ - alice-dev, bob-devops, diana-viewer       │
└──────────────┬──────────────────────────────┘
               │ assigned to
               ↓
┌─────────────────────────────────────────────┐
│ Permission Sets                             │
│ - EKSDeveloper, EKSDevOps, EKSReadOnly      │
└──────────────┬──────────────────────────────┘
               │ AWS provisions (3 min)
               ↓
┌─────────────────────────────────────────────┐
│ SSO Roles (auto-created)                    │
│ - AWSReservedSSO_EKSDeveloper_*             │
│ - AWSReservedSSO_EKSDevOps_*                │
│ - AWSReservedSSO_EKSReadOnly_*              │
└──────────────┬──────────────────────────────┘
               │ EKS Access Entry maps
               ↓
┌─────────────────────────────────────────────┐
│ K8s Groups (in RBAC)                        │
│ - developers, devops, viewers               │
└──────────────┬──────────────────────────────┘
               │ RoleBinding
               ↓
┌─────────────────────────────────────────────┐
│ K8s Roles (permissions)                     │
│ - developer-role, devops-role, viewer-role  │
└─────────────────────────────────────────────┘
```

## Key Features

✅ **Fully automated** - One terraform apply  
✅ **Async handling** - Waits for SSO roles  
✅ **GitOps** - RBAC in Git, auto-deployed  
✅ **Scalable** - Add users in Terraform  
✅ **Production-ready** - Same pattern as with SAML  

## Troubleshooting

### "No SSO roles found"
- Wait 3 minutes after user assignment
- Check: `aws iam list-roles --path-prefix /aws-reserved/sso.amazonaws.com/`

### "Access denied" in kubectl
- Verify RBAC deployed: `kubectl get rolebinding -n dev`
- Check access entry: `aws eks list-access-entries --cluster-name eks-gitops-lab`

### "Email not received"
- Check spam folder
- Verify email in Identity Center console
- Resend invitation from console

## Migration from IAM Users

If you have existing IAM users:
1. Deploy Identity Center setup
2. Test with SSO users
3. Remove IAM user access entries
4. Delete IAM users

K8s RBAC stays the same - only IAM source changes!
