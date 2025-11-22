# Full GitOps with ACK Controller

## Architecture

```
Terraform (Infrastructure)
├─ VPC, EKS, ArgoCD
├─ Identity Center users
├─ Permission sets
└─ User assignments
    ↓ (AWS provisions SSO roles - 3 min)

ArgoCD (Configuration - Everything in Git!)
├─ ACK EKS Controller (manages AWS resources from K8s)
├─ RBAC (namespaces, roles, rolebindings)
└─ AccessEntry CRDs (maps SSO roles → K8s groups)
    ↓
ACK Controller (Reconciliation Loop)
└─ Creates actual EKS Access Entries in AWS
```

## What's Different from Before

### Before (Terraform manages access entries):
```
Terraform: Creates users + permission sets + access entries
ArgoCD: Manages K8s RBAC only
```

### Now (ACK manages access entries):
```
Terraform: Creates users + permission sets only
ArgoCD: Manages K8s RBAC + AccessEntry CRDs
ACK: Creates access entries in AWS from CRDs
```

## The Flow

```
1. terraform apply
   ├─ Creates Identity Center users
   ├─ Creates permission sets
   ├─ Assigns users to permission sets
   └─ Waits 3 min for SSO roles

2. ArgoCD deploys (automatic)
   ├─ ACK EKS Controller
   ├─ RBAC (namespaces, roles, rolebindings)
   └─ AccessEntry CRDs

3. ACK Controller (automatic)
   ├─ Watches for AccessEntry CRDs
   ├─ Calls AWS EKS API
   └─ Creates access entries in AWS

4. Self-healing!
   ├─ Someone deletes access entry in AWS
   ├─ ACK detects drift (30s)
   └─ ACK recreates it from CRD
```

## Files Created

### Terraform (No changes to existing)
- `terraform/modules/iam-identity-center/` - Creates users, no access entries

### ArgoCD Apps
- `apps/ack-eks-controller/` - ACK controller Helm chart
- `apps/access-entries/` - AccessEntry CRDs
- `argocd-apps/ack-eks-controller.yaml` - ArgoCD app
- `argocd-apps/access-entries.yaml` - ArgoCD app

### AccessEntry CRDs (in Git!)
```yaml
apiVersion: eks.services.k8s.aws/v1alpha1
kind: AccessEntry
metadata:
  name: eksdeveloper
spec:
  clusterName: eks-gitops-lab
  principalARN: arn:aws:iam::123:role/.../AWSReservedSSO_EKSDeveloper_*
  kubernetesGroups:
    - developers
```

## Benefits

### ✅ Full GitOps
- Everything in Git (infrastructure + configuration)
- Single source of truth
- Audit trail for all changes

### ✅ Self-Healing
- ArgoCD heals K8s resources
- ACK heals AWS resources
- Both reconcile every 30 seconds

### ✅ Declarative
- Describe desired state in Git
- Controllers ensure actual state matches
- No imperative commands

### ✅ Scalable
- Add new user: Update Git, push
- No Terraform apply needed
- ArgoCD + ACK handle everything

## Adding New Users

### Option 1: Add to Terraform (requires apply)
```hcl
# terraform/main.tf
users = {
  # Existing...
  emma-dev = {
    email = "emma@example.com"
    ...
  }
}
```

### Option 2: Add AccessEntry CRD only (no Terraform!)
```yaml
# apps/access-entries/templates/emma.yaml
apiVersion: eks.services.k8s.aws/v1alpha1
kind: AccessEntry
metadata:
  name: emma-dev
spec:
  principalARN: arn:aws:iam::123:user/emma
  kubernetesGroups:
    - developers
```

**Just commit to Git - ArgoCD + ACK handle the rest!**

## Monitoring

### Check ACK Controller
```bash
kubectl get pods -n ack-system
kubectl logs -n ack-system -l app.kubernetes.io/name=eks-chart
```

### Check AccessEntry CRDs
```bash
kubectl get accessentry -n ack-system
kubectl describe accessentry eksdeveloper -n ack-system
```

### Check Actual Access Entries in AWS
```bash
aws eks list-access-entries --cluster-name eks-gitops-lab
```

### Check Sync Status
```bash
# ArgoCD
kubectl get application -n argocd

# AccessEntry status
kubectl get accessentry -n ack-system -o yaml
# Look for: status.conditions
```

## Troubleshooting

### AccessEntry stuck in "Syncing"
```bash
# Check ACK controller logs
kubectl logs -n ack-system -l app.kubernetes.io/name=eks-chart --tail=50

# Common issues:
# - IAM role doesn't exist yet (wait 3 min after Terraform)
# - ACK controller doesn't have permissions
# - Invalid principal ARN
```

### Access entry not created in AWS
```bash
# Verify CRD exists
kubectl get accessentry -n ack-system

# Check CRD status
kubectl describe accessentry eksdeveloper -n ack-system

# Check ACK controller has IRSA role
kubectl get sa ack-eks-controller -n ack-system -o yaml
```

### Self-healing test
```bash
# Delete access entry in AWS
aws eks delete-access-entry \
  --cluster-name eks-gitops-lab \
  --principal-arn arn:aws:iam::123:role/.../AWSReservedSSO_EKSDeveloper_*

# Wait 30 seconds
# Check if ACK recreated it
aws eks list-access-entries --cluster-name eks-gitops-lab
```

## Interview Talking Points

> **"I implemented full GitOps with AWS Controllers for Kubernetes:**
>
> **1. Terraform manages infrastructure** - Users, permission sets, cluster
>
> **2. ArgoCD manages configuration** - RBAC and AccessEntry CRDs in Git
>
> **3. ACK Controller bridges K8s and AWS** - Creates actual access entries from CRDs
>
> **Benefits:**
> - Everything in Git (single source of truth)
> - Self-healing at both layers (ArgoCD + ACK)
> - Declarative (describe desired state, controllers handle it)
> - Scalable (add users via Git PR, no Terraform needed)
>
> **This is the most advanced GitOps pattern - same approach used by companies like Weaveworks and Flux."**

## Next Steps

1. Deploy and test
2. Try self-healing (delete access entry, watch it recreate)
3. Add a new user via Git PR only
4. Show in interview!

**This is production-grade GitOps!** 🚀
