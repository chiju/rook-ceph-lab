# EKS GitOps Lab

Production-ready Amazon EKS infrastructure with GitOps using ArgoCD, fully automated via GitHub Actions and Terraform.

## 🚀 From Scratch to Production

This project demonstrates a **complete GitOps workflow** from zero to a fully automated Kubernetes cluster:

1. **Bootstrap** → Create S3 backend for Terraform state
2. **Setup** → Configure IAM role with OIDC authentication
3. **Deploy** → Push to GitHub, infrastructure deploys automatically
4. **GitOps** → ArgoCD syncs applications from Git every 30 seconds
5. **Scale** → Karpenter autoscales nodes, KEDA autoscales pods
6. **Monitor** → Prometheus + Grafana for metrics, Loki for logs
7. **Cleanup** → One command destroys everything

**Total setup time:** ~20 minutes (mostly waiting for EKS cluster)

**Manual steps:** Only 3 (bootstrap, OIDC, GitHub App)

**Everything else:** Fully automated via GitHub Actions and ArgoCD

## 🎯 What Gets Deployed

### Infrastructure
- **EKS Cluster**: Kubernetes 1.34 with managed node groups (2 t3.medium nodes)
- **Networking**: VPC with public/private subnets across 2 AZs
- **Storage**: EBS-backed persistent volumes
- **Autoscaling**: Karpenter for intelligent node scaling

### GitOps & Automation
- **ArgoCD**: Automated application deployment with app-of-apps pattern
- **GitHub Actions**: OIDC-based CI/CD pipeline
- **Terraform**: Infrastructure as Code with S3 remote state

### Applications & Services
- **nginx**: Web server with KEDA autoscaling
- **KEDA**: Event-driven pod autoscaling (CPU/Memory triggers)
- **Karpenter**: Intelligent node autoscaling and bin-packing
- **Prometheus Stack**: Metrics collection and alerting
- **Grafana**: Metrics visualization with CloudWatch integration
- **Loki**: Log aggregation backend
- **Promtail**: Log collection from all pods
- **Event Exporter**: Kubernetes events to Loki for Grafana visualization

### AWS Controllers for Kubernetes (ACK)
- **ACK EKS Controller**: Manages EKS resources via Kubernetes CRDs
- **Access Entries**: Automatically created from SSO roles
- **GitOps-native**: Self-healing access management

## 🔐 Security Features

### Authentication & Authorization
- ✅ **AWS OIDC**: No stored credentials
- ✅ **Federated Authentication**: GitHub Actions authenticates via OIDC
- ✅ **IAM Identity Center**: SSO with multiple users and permission sets
- ✅ **ACK EKS Controller**: Automatic AccessEntry creation from SSO roles
- ✅ **RBAC**: Role-based access control with namespace isolation
- ✅ **IAM Roles**: Least privilege access for all services
- ✅ **IRSA**: IAM Roles for Service Accounts (Karpenter, Grafana)
- ✅ **Encrypted State**: S3 backend with encryption at rest

### Data Protection
- ✅ **No Secrets in Code**: All sensitive data in GitHub Secrets
- ✅ **Branch Protection**: PRs required via workflow concurrency
- ✅ **State Locking**: Native S3 locking prevents concurrent modifications

### Security Scanning
- ✅ **Checkov**: IaC security scanning in CI/CD pipeline
- ✅ **Terraform Validation**: Format and validation checks
- ℹ️ **Note**: Checkov chosen for deep Terraform analysis

## 📋 Prerequisites

- AWS CLI configured (`aws configure`)
- GitHub CLI (`gh auth login`)
- Terraform (v1.13.5+)
- kubectl
- Git

## 🚀 Quick Start (3 Steps)

### 1. Bootstrap Backend

```bash
./scripts/bootstrap-backend.sh
```

**What it does:**
- Creates S3 bucket for Terraform state (with versioning & encryption)
- Uses native S3 locking (no DynamoDB needed)
- **Automatically updates** `terraform/backend.tf` with bucket name

**Output:** 
```
✅ Backend created successfully!
✅ Updated terraform/backend.tf automatically!
```

### 2. Setup OIDC Access

```bash
./scripts/setup-oidc-access.sh
```

**What it does:**
- Creates GitHub OIDC provider in AWS (if not exists)
- Creates IAM role for GitHub Actions
- Configures federated credentials
- **Automatically adds 3 GitHub secrets**

**Output:**
```
✅ OIDC setup complete!
✅ GitHub secrets added!
```

### 3. Create GitHub App

**Go to:** https://github.com/settings/apps/new

**Settings:**
- Name: `ArgoCD-EKS-GitOps`
- Homepage: `https://github.com/YOUR_USERNAME/eks-gitops-lab`
- Webhook: ✅ **Uncheck "Active"**
- Repository permissions:
  - Contents: `Read-only`
  - Metadata: `Read-only` (mandatory)
- Install: `Only on this account`

**After creation:**
1. Generate private key (downloads `.pem` file)
2. Note App ID (shown on page)
3. Install app → Select `eks-gitops-lab` repo
4. Note Installation ID (from URL: `.../installations/XXXXXXXX`)

**Store secrets:**
```bash
cd ~/Downloads
gh secret set ARGOCD_APP_PRIVATE_KEY < argocd-eks-gitops.*.private-key.pem
gh secret set ARGOCD_APP_ID -b "YOUR_APP_ID"
gh secret set ARGOCD_APP_INSTALLATION_ID -b "YOUR_INSTALLATION_ID"
```

### 4. Deploy

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

**That's it!** GitHub Actions will:
1. Run terraform plan (security scan)
2. Deploy EKS cluster (~15 minutes)
3. Install ArgoCD
4. Update app configs with cluster info
5. Deploy all applications automatically

## 🏗️ Architecture

### Infrastructure Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                           │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                  │ │
│  │                                                       │ │
│  │  ┌──────────────────┐      ┌──────────────────┐     │ │
│  │  │  Public Subnet   │      │  Public Subnet   │     │ │
│  │  │  10.0.1.0/24     │      │  10.0.2.0/24     │     │ │
│  │  │  (AZ-1)          │      │  (AZ-2)          │     │ │
│  │  │  - NAT Gateway   │      │                  │     │ │
│  │  └──────────────────┘      └──────────────────┘     │ │
│  │           │                         │                │ │
│  │  ┌──────────────────┐      ┌──────────────────┐     │ │
│  │  │ Private Subnet   │      │ Private Subnet   │     │ │
│  │  │ 10.0.37.0/24     │      │ 10.0.60.0/24     │     │ │
│  │  │ (AZ-1)           │      │ (AZ-2)           │     │ │
│  │  │ ┌──────────────┐ │      │ ┌──────────────┐ │     │ │
│  │  │ │ EKS Nodes    │ │      │ │ EKS Nodes    │ │     │ │
│  │  │ │ t3.medium    │ │      │ │ t3.medium    │ │     │ │
│  │  │ └──────────────┘ │      │ └──────────────┘ │     │ │
│  │  └──────────────────┘      └──────────────────┘     │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### GitOps Flow

```
Developer → PR → Plan → Review → Merge → Apply → Update Configs → ArgoCD Syncs
```

### Application Deployment

```
┌──────────────────────────────────────────────────────────────┐
│                        ArgoCD                                │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  core-apps (App of Apps)                                    │
│  ├─ Monitors: argocd-apps/ directory                       │
│  ├─ Auto-sync: Every 30 seconds                            │
│  └─ Auto-prune: Removes deleted apps                       │
│                                                              │
│  Applications                                                │
│  ├─ nginx (with KEDA autoscaling)                          │
│  ├─ keda (pod autoscaling controller)                      │
│  ├─ karpenter (node autoscaling)                           │
│  ├─ kube-prometheus-stack (monitoring)                     │
│  ├─ loki (log aggregation)                                 │
│  └─ promtail (log collection)                              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
.
├── .github/workflows/
│   ├── terraform.yml           # Main CI/CD pipeline
│   ├── terraform-destroy.yml   # Infrastructure cleanup
│   └── update-app-values.yml   # Update configs from Terraform
├── apps/                       # Helm charts for applications
│   ├── nginx/
│   ├── keda/
│   ├── karpenter/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   ├── promtail/
│   ├── event-exporter/        # Kubernetes events to Loki
│   ├── ack-eks-controller/    # ACK EKS controller
│   ├── access-entries/        # EKS access entries via ACK
│   └── rbac-setup/            # RBAC roles and bindings
├── argocd-apps/               # ArgoCD application definitions
│   ├── nginx.yaml
│   ├── keda.yaml
│   ├── karpenter.yaml
│   ├── kube-prometheus-stack.yaml
│   ├── loki.yaml
│   ├── promtail.yaml
│   ├── event-exporter.yaml
│   ├── ack-eks-controller.yaml
│   ├── access-entries.yaml
│   └── rbac-setup.yaml
├── terraform/                 # Terraform infrastructure
│   ├── modules/
│   │   ├── aks/              # EKS cluster configuration
│   │   ├── argocd/           # ArgoCD Helm deployment
│   │   └── vpc/              # Virtual network
│   ├── backend.tf            # Terraform backend configuration
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output definitions
│   └── provider.tf           # Provider configuration
├── scripts/                   # Automation scripts
│   ├── bootstrap-backend.sh
│   ├── setup-oidc-access.sh
│   └── cleanup-all.sh
└── README.md
```

## 🎮 Accessing Services

### EKS Cluster

```bash
# Get credentials
aws eks update-kubeconfig --name eks-gitops-lab --region eu-central-1

# Check cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

### ArgoCD UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Open browser
open https://localhost:8080
# Username: admin
# Password: (from above command)
```

### Grafana

```bash
# Port forward
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# Get password
kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d

# Open browser
open http://localhost:3000
# Username: admin
# Password: (from above command)
```

### Prometheus

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
open http://localhost:9090
```

### AWS SSO Access

```bash
# Configure SSO profile
aws configure sso
# SSO start URL: https://d-99675f4fc7.awsapps.com/start
# SSO Region: eu-central-1
# Account: 432801802107
# Role: EKSDeveloper / EKSDevOps / EKSReadOnly

# Login
aws sso login --profile <profile-name>

# Access EKS
aws eks update-kubeconfig --name eks-gitops-lab --region eu-central-1 --profile <profile-name>
kubectl get pods -n dev  # Developer access
kubectl get nodes        # DevOps access
```

**User Roles:**
- **EKSDeveloper**: Full access to `dev` namespace only
- **EKSDevOps**: Full cluster access (all namespaces, nodes)
- **EKSReadOnly**: Read-only access to all namespaces

## 🧹 Cleanup

### Complete Cleanup

```bash
./scripts/cleanup-all.sh
```

This removes:
- ✅ IAM role
- ✅ S3 bucket and all objects
- ✅ GitHub secrets
- ✅ Local Terraform state files

### Partial Cleanup (Keep Backend)

```bash
# Destroy infrastructure only (manual trigger required)
gh workflow run terraform-destroy.yml -f confirm=destroy
```

## 🐛 Troubleshooting

### Issue: Workflow fails with permission error

**Solution:** The IAM role needs proper permissions. Check:
```bash
aws iam get-role --role-name GitHubActionsEKSRole
```

### Issue: ArgoCD not syncing apps

**Possible causes:**
1. GitHub token expired
2. Repository URL incorrect
3. Branch name mismatch

**Solution:**
```bash
# Check ArgoCD repo secret
kubectl get secret argocd-repo -n argocd -o yaml

# Update if needed
kubectl delete secret argocd-repo -n argocd
# Re-run update-app-values workflow
gh workflow run update-app-values.yml
```

### Issue: Karpenter not scaling nodes

**Solution:** Check if Karpenter has correct cluster info:
```bash
# Manually trigger update workflow
gh workflow run update-app-values.yml

# Verify Karpenter config
kubectl get ec2nodeclass -o yaml
```

### Issue: Pods pending due to insufficient resources

**Solution:** Karpenter will automatically provision nodes. Check:
```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Check pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```

## 📊 Monitoring & Observability

### Metrics (Prometheus + Grafana)

- **Node metrics**: CPU, memory, disk, network
- **Pod metrics**: Resource usage per pod
- **Cluster metrics**: Overall cluster health
- **CloudWatch integration**: Grafana can query CloudWatch

### Logs (Loki + Promtail)

- **Centralized logging**: All pod logs in one place
- **Query language**: LogQL for powerful log queries
- **Retention**: Configurable log retention policies
- **Integration**: Grafana dashboards for log visualization

### Kubernetes Events (Event Exporter)

- **Event collection**: All K8s events sent to Loki
- **Grafana visualization**: View events in Grafana Explore
- **Query**: `{app="event-exporter"}` or `{type="Warning"}`
- **Filtering**: By namespace, reason, type, kind, name
- **Pod metrics**: Resource usage per pod
- **Cluster metrics**: Overall cluster health
- **CloudWatch integration**: Grafana can query CloudWatch

### Logs (Loki + Promtail)

- **Centralized logging**: All pod logs in one place
- **Query language**: LogQL for powerful log queries
- **Retention**: Configurable log retention policies
- **Integration**: Grafana dashboards for log visualization

### Autoscaling

**KEDA (Pod Autoscaling):**
- CPU-based: Scale on CPU utilization
- Memory-based: Scale on memory usage
- Custom metrics: Scale on any Prometheus metric

**Karpenter (Node Autoscaling):**
- Intelligent provisioning: Right-sized nodes
- Bin-packing: Efficient resource utilization
- Fast scaling: Nodes ready in ~2 minutes
- Cost optimization: Spot instances support

## 💰 Cost Optimization

### Current Setup (2 nodes)

- **EKS Control Plane**: ~$73/month
- **EC2**: 2 x t3.medium (~$60/month)
- **NAT Gateway**: ~$32/month
- **EBS Volumes**: ~$10/month
- **Total**: ~$175/month

### Cost Saving Tips

1. **Use Karpenter with Spot** - Save up to 90% on compute
2. **Scale down** when not in use
3. **Use smaller node sizes** for dev/test
4. **Destroy infrastructure** when not needed

```bash
# Destroy when not in use
gh workflow run terraform-destroy.yml -f confirm=destroy

# Redeploy when needed
git commit --allow-empty -m "Redeploy" && git push
```

## 🔒 Security Best Practices

### Implemented

- ✅ No credentials in code or version control
- ✅ Federated authentication (OIDC)
- ✅ Encrypted Terraform state
- ✅ IAM roles with least privilege
- ✅ IRSA for pod-level permissions
- ✅ Secrets stored in GitHub Secrets
- ✅ Workflow concurrency control

### Recommended for Production

**Security Enhancements:**
- 🔲 **External Secrets Operator** - Sync secrets from AWS Secrets Manager
- 🔲 **Private Cluster Endpoint** - Restrict API server access
- 🔲 **Network Policies** - Control pod-to-pod traffic
- 🔲 **Pod Security Standards** - Enforce security policies
- 🔲 **AWS Config** - Compliance and governance
- 🔲 **KMS Encryption** - Encrypt Kubernetes secrets at rest

**Infrastructure Improvements:**
- 🔲 **Separate Node Groups** - System vs user workloads
- 🔲 **Production Instance Types** - t3.large or larger
- 🔲 **Resource Limits** - CPU/memory limits on all pods
- 🔲 **Velero Backups** - Disaster recovery
- 🔲 **Multi-region** - High availability

**Operational:**
- 🔲 **Cost Alerts** - AWS Budgets and alerts
- 🔲 **Terraform Workspaces** - Dev/staging/prod environments
- 🔲 **Runbooks** - Incident response procedures
- 🔲 **SLO/SLA Monitoring** - Service level objectives

## 📚 What's Automated

- ✅ S3 backend creation
- ✅ Backend configuration auto-update
- ✅ IAM role creation and configuration
- ✅ OIDC provider setup
- ✅ GitHub secrets (3 of 5 automated)
- ✅ EKS cluster deployment
- ✅ ArgoCD installation and configuration
- ✅ Application deployment via GitOps
- ✅ Karpenter configuration with cluster info
- ✅ Grafana CloudWatch integration
- ✅ KEDA autoscaling setup
- ✅ Monitoring stack deployment

## ✋ What's Manual

- ❌ Add `GIT_USERNAME` secret (one-time)
- ❌ Add `ARGOCD_GITHUB_TOKEN` secret (one-time)

## 🎓 Learning Resources

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Karpenter Documentation](https://karpenter.sh/)
- [KEDA Documentation](https://keda.sh/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitOps Principles](https://opengitops.dev/)

## 📝 License

MIT

## 🤝 Contributing

This is a learning lab project. Feel free to fork and adapt for your needs!

## ⚠️ Important Notes

### Current Setup
- **Purpose**: Learning and portfolio demonstration
- **Environment**: Lab/Development
- **Instance Type**: t3.medium (cost-optimized)
- **Security**: Basic (OIDC, IRSA, encrypted state)

### For Production Use
This setup provides a **solid foundation** but requires these enhancements:

**Must Have:**
- Private cluster endpoint
- Network policies
- Resource limits on all pods
- External Secrets Operator with AWS Secrets Manager
- Velero backups
- Production instance types (t3.large+)
- KMS encryption for Kubernetes secrets

**Should Have:**
- Separate node groups (system/user)
- Cost alerts and budgets
- Multi-environment setup (dev/staging/prod)
- Comprehensive monitoring and alerting
- Disaster recovery plan

**Cost Considerations:**
- Current setup: ~$175/month
- Production setup: ~$400-600/month (with redundancy)
- Remember to destroy resources when not in use
