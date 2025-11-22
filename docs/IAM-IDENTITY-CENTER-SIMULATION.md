# IAM Identity Center Simulation

This feature demonstrates **industry-standard EKS access management** without requiring AWS Organizations.

## What This Simulates

### Real IAM Identity Center Flow:
```
Developer → Google SAML → IAM Identity Center → Permission Set → EKS Access Entry → K8s RBAC
```

### Our Simulation:
```
Developer → IAM User → IAM Role (Permission Set) → EKS Access Entry → K8s RBAC
```

**Same end result, no AWS Organization needed!**

---

## Architecture

### Terraform (Outside Kubernetes)
```
terraform/modules/iam-sso-sim/
├── Creates 4 IAM users (simulated SSO users)
├── Creates 4 IAM roles (simulated permission sets)
├── Creates EKS Access Entries
└── Outputs AWS CLI config
```

### ArgoCD (Inside Kubernetes)
```
apps/rbac-setup/
├── Creates namespaces (dev, staging)
├── Creates RBAC roles
├── Creates resource quotas
└── Auto-syncs from Git
```

---

## Users & Access Levels

| User | Permission Set | EKS Policy | K8s Access |
|------|----------------|------------|------------|
| alice-admin | PlatformAdmin | ClusterAdmin | Full cluster access |
| bob-devops | DevOpsEngineer | Admin | Multi-namespace |
| charlie-dev | Developer | Edit | Namespace-scoped (dev) |
| diana-viewer | ReadOnly | View | View-only |

---

## Setup Instructions

### 1. Enable the Module in Terraform

Add to `terraform/main.tf`:

```hcl
module "iam_sso_sim" {
  source = "./modules/iam-sso-sim"

  cluster_name = var.cluster_name
  aws_region   = var.aws_region

  depends_on = [module.eks]
}

output "iam_sso_setup" {
  value     = module.iam_sso_sim.setup_instructions
  sensitive = false
}

output "aws_config_profiles" {
  value     = module.iam_sso_sim.aws_config_profiles
  sensitive = true
}
```

### 2. Deploy via GitHub Actions

```bash
git add .
git commit -m "feat: Add IAM Identity Center simulation"
git push origin feature/iam-identity-center-simulation
```

GitHub Actions will:
1. Run Terraform (creates IAM users/roles)
2. ArgoCD auto-deploys RBAC setup

### 3. Configure AWS CLI

```bash
# Get the AWS config profiles
terraform output -raw aws_config_profiles >> ~/.aws/config

# Or manually from Terraform output
terraform output aws_config_profiles
```

### 4. Test Each User

#### Alice (Platform Admin)
```bash
aws eks update-kubeconfig \
  --name eks-lab \
  --profile eks-lab-alice-admin \
  --region eu-central-1

kubectl get nodes
kubectl get pods -A
kubectl delete namespace test  # Works
```

#### Bob (DevOps Engineer)
```bash
aws eks update-kubeconfig \
  --name eks-lab \
  --profile eks-lab-bob-devops \
  --region eu-central-1 \
  --alias eks-lab-devops

kubectl get pods -n dev
kubectl get pods -n staging
kubectl get nodes  # Works (can view)
```

#### Charlie (Developer)
```bash
aws eks update-kubeconfig \
  --name eks-lab \
  --profile eks-lab-charlie-dev \
  --region eu-central-1 \
  --alias eks-lab-dev

kubectl get pods -n dev  # Works
kubectl create deployment nginx --image=nginx -n dev  # Works
kubectl get pods -n staging  # Limited (read-only)
kubectl get nodes  # Forbidden
```

#### Diana (Read-Only)
```bash
aws eks update-kubeconfig \
  --name eks-lab \
  --profile eks-lab-diana-viewer \
  --region eu-central-1 \
  --alias eks-lab-ro

kubectl get pods -A  # Works
kubectl get secrets -A  # Forbidden
kubectl delete pod xxx  # Forbidden
```

---

## RBAC Details

### Developer Access (charlie-dev)

**In dev namespace:**
- ✅ Full CRUD on pods, deployments, services
- ✅ Can exec into pods
- ✅ Can view secrets (read-only)
- ✅ Can create jobs, ingresses

**In staging namespace:**
- ✅ Read-only access
- ✅ Can update deployments (for rollouts)
- ✅ Can view logs

**Cluster-wide:**
- ❌ Cannot view nodes
- ❌ Cannot access kube-system
- ❌ Cannot create namespaces

### DevOps Access (bob-devops)

- ✅ Full access to dev and staging namespaces
- ✅ Can view nodes
- ✅ Can create namespaces
- ✅ Read-only to kube-system
- ❌ Cannot modify cluster-level resources

### Read-Only Access (diana-viewer)

- ✅ View all resources
- ❌ Cannot modify anything
- ❌ Cannot view secrets

---

## Testing Scenarios

### Scenario 1: Developer deploys to dev
```bash
# As charlie-dev
kubectl config use-context eks-lab-dev

# Create deployment
kubectl create deployment test-app --image=nginx -n dev
kubectl get pods -n dev  # ✅ Works

# Try to delete namespace
kubectl delete namespace dev  # ❌ Forbidden
```

### Scenario 2: DevOps troubleshoots production
```bash
# As bob-devops
kubectl config use-context eks-lab-devops

# View all namespaces
kubectl get pods -A  # ✅ Works

# Check node status
kubectl get nodes  # ✅ Works
kubectl describe node xxx  # ✅ Works

# Try to modify kube-system
kubectl delete pod -n kube-system coredns-xxx  # ❌ Forbidden
```

### Scenario 3: Auditor reviews cluster
```bash
# As diana-viewer
kubectl config use-context eks-lab-ro

# View everything
kubectl get all -A  # ✅ Works

# Try to view secrets
kubectl get secrets -A  # ❌ Forbidden

# Try to delete
kubectl delete pod xxx  # ❌ Forbidden
```

---

## Comparison: Simulation vs Real IAM Identity Center

| Feature | Simulation | Real IAM Identity Center |
|---------|------------|--------------------------|
| **Cost** | $0 | $0 |
| **Setup Time** | 5 minutes | 30 minutes |
| **AWS Org Required** | ❌ No | ✅ Yes |
| **Browser SSO** | ❌ No | ✅ Yes |
| **CLI Access** | ✅ Yes | ✅ Yes |
| **RBAC Integration** | ✅ Yes | ✅ Yes |
| **Multi-Account** | ❌ No | ✅ Yes |
| **Learning Value** | ✅ Perfect | ✅ Perfect |

---

## Migration to Real IAM Identity Center

When you're ready for production:

1. **Enable IAM Identity Center** in your AWS Organization
2. **Connect Google Workspace SAML**
3. **Create Permission Sets** (same names as our roles)
4. **Update EKS Access Entries** (change role ARNs)
5. **Delete simulated users** (cleanup)

The RBAC stays the same! Only the IAM layer changes.

---

## Cleanup

To remove the simulation:

```bash
# Remove module from main.tf
# Push to GitHub
git commit -m "chore: Remove IAM SSO simulation"
git push

# Terraform will destroy IAM users/roles
# ArgoCD will remove RBAC (if you delete the app)
```

---

## Key Learnings

1. ✅ **EKS Access Entries** are the modern way (not aws-auth ConfigMap)
2. ✅ **RBAC** enforces namespace isolation
3. ✅ **GitOps** manages all K8s resources
4. ✅ **Terraform** only manages AWS infrastructure
5. ✅ **IAM Identity Center** is free and industry standard

---

## Next Steps

- [ ] Test all 4 user personas
- [ ] Deploy a test app to dev namespace
- [ ] Try to break permissions (verify RBAC works)
- [ ] Review CloudTrail logs (audit trail)
- [ ] Plan migration to real IAM Identity Center

---

## Questions?

This simulation demonstrates exactly how companies manage EKS access in production. The only difference is using IAM users instead of SSO - the RBAC and access patterns are identical!
