# Rook Ceph Lab - Distributed Storage Platform

A complete Rook Ceph deployment on Amazon EKS demonstrating unified block, file, and object storage from a single distributed system.

## 🎯 What This Lab Provides

### **Complete Storage Platform**
- **Block Storage (RBD)** - Persistent volumes for databases and applications
- **File Storage (CephFS)** - Shared storage across multiple pods  
- **Object Storage (RGW)** - S3-compatible API for backups and archives

### **Architecture Patterns**
- **GitOps Deployment** - Infrastructure as Code with ArgoCD
- **Kubernetes Native** - Rook operator for lifecycle management
- **Scalable Design** - Ready for multi-tenant applications
- **Production Ready** - Proper dependency management and health checks

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Cluster (3 Nodes)                   │
├─────────────────────────────────────────────────────────────┤
│                   Rook Ceph Platform                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │    MON      │ │    MGR      │ │    OSD      │          │
│  │ (Monitor)   │ │ (Manager)   │ │ (Storage)   │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
│                                                             │
│  ┌─────────────┐ ┌─────────────┐                          │
│  │    MDS      │ │    RGW      │                          │
│  │ (Metadata)  │ │ (S3 Gateway)│                          │
│  └─────────────┘ └─────────────┘                          │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼──────┐    ┌────────▼──────┐    ┌────────▼──────┐
│ Block Storage│    │Object Storage │    │ File Storage  │
│    (RBD)     │    │     (S3)      │    │   (CephFS)    │
│              │    │               │    │               │
│ StorageClass:│    │ StorageClass: │    │ StorageClass: │
│rook-ceph-    │    │rook-ceph-     │    │  rook-cephfs  │
│block         │    │bucket         │    │               │
└──────────────┘    └───────────────┘    └───────────────┘
```

## 🚀 Quick Start

### **Prerequisites**
- AWS CLI configured
- kubectl installed
- Terraform installed
- GitHub CLI (gh) installed

### **1. Clone Repository**
```bash
git clone https://github.com/chiju/rook-ceph-lab.git
cd rook-ceph-lab
```

### **2. Setup Scripts**
```bash
# Create S3 backend for Terraform state
./scripts/bootstrap-backend.sh

# Setup GitHub OIDC authentication
./scripts/setup-oidc-access.sh
```

### **3. Create GitHub App (One-time Setup)**

**Create a dedicated GitHub App for this Rook Ceph lab:**

**Go to:** https://github.com/settings/apps/new

**Required Settings:**
- **Name:** `ArgoCD-Rook-Ceph-Lab` (dedicated to this repo)
- **Homepage:** `https://github.com/chiju/rook-ceph-lab`
- **Webhook:** ✅ **Uncheck "Active"** (we don't need webhooks)
- **Repository permissions:**
  - **Contents:** `Read-only` (ArgoCD needs to read your repo)
  - **Metadata:** `Read-only` (automatically required)
- **Where can this app be installed:** `Only on this account`

**After creation:**
1. **Generate private key** → Downloads `.pem` file
2. **Note App ID** → Shown on the app page (e.g., `2336285`)
3. **Install app** → Click "Install App" → Select **ONLY** `rook-ceph-lab` repository
4. **Note Installation ID** → From URL: `github.com/settings/installations/XXXXXXXX` (e.g., `96060885`)

**Store GitHub App secrets:**
```bash
cd ~/Downloads
gh secret set ARGOCD_APP_PRIVATE_KEY < argocd-rook-ceph-lab.*.private-key.pem
gh secret set ARGOCD_APP_ID -b "2336285"
gh secret set ARGOCD_APP_INSTALLATION_ID -b "96060885"
```

**✅ Dedicated GitHub App configured! This keeps the Rook Ceph lab isolated.**

### **4. Deploy**
```bash
git add .
git commit -m "Initial Rook Ceph deployment"
git push origin main
```

**That's it!** GitHub Actions will deploy the complete Rook Ceph platform.

### **5. Verify Deployment**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-central-1 --name rook-ceph-lab

# Check ArgoCD applications
kubectl get applications -n argocd

# Check storage classes
kubectl get storageclass | grep ceph

# Check test results
kubectl logs -l app=ceph-comprehensive-test --tail=10
```

## 📦 ArgoCD Applications

| **Application** | **Purpose** | **Wave** |
|-----------------|-------------|----------|
| `rook-operator` | Installs Ceph operator | 0 |
| `ceph-cluster` | Creates storage cluster (MON/MGR/OSD) | 1 |
| `ceph-block-storage` | Provides block storage interface | 2 |
| `ceph-object-storage` | Provides S3-compatible storage | 3 |
| `ceph-file-storage` | Provides shared file storage | 3 |
| `ceph-test-apps` | Validates all storage types | 4 |

## 💾 Storage Usage Examples

### **Block Storage (ReadWriteOnce)**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  storageClassName: rook-ceph-block
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
```

### **File Storage (ReadWriteMany)**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
spec:
  storageClassName: rook-cephfs
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 5Gi
```

### **Object Storage (S3 Buckets)**
```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: backup-bucket
spec:
  storageClassName: rook-ceph-bucket
```

## 🔧 Production Scaling

### **Current Lab Configuration**
- **MON:** 1 instance (minimal for testing)
- **MGR:** 1 instance (minimal for testing)
- **OSD:** 1 instance (minimal for testing)
- **Storage:** ~25Gi total (EBS backend)
- **Replication:** 1x (no redundancy)

### **Production Configuration**
```yaml
# Recommended production setup
mon:
  count: 3  # Odd number for quorum
mgr:
  count: 2  # Active/standby
storage:
  storageClassDeviceSets:
  - count: 6  # Multiple OSDs per node
    portable: true
    resources:
      requests:
        storage: 100Gi  # Larger storage volumes
```

### **High Availability Features**
- **Multiple MONs** for consensus and fault tolerance
- **Multiple MGRs** for manager failover  
- **Multiple OSDs** with configurable replication
- **Multi-AZ deployment** for disaster recovery

## 🎯 Use Cases

### **Application Storage**
- **Databases:** PostgreSQL, MySQL with persistent block storage
- **Web Applications:** Shared file storage for uploads and configs
- **Backup Systems:** S3-compatible storage for automated backups
- **CI/CD:** Shared build artifacts and container registries

### **Platform Services**
- **Monitoring:** Persistent storage for Prometheus metrics
- **Logging:** Object storage for log archives
- **Container Registry:** S3 backend for Harbor or similar
- **Development:** Shared storage for development environments

## 🔧 Ceph Admin Tools

### **Using the Toolbox**
The Ceph toolbox pod provides all admin commands for managing your cluster:

```bash
# Check cluster status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status

# Check OSD status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd status

# Check storage usage
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df

# List all pools
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool ls

# List realms
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- radosgw-admin realm list
```

### **S3 User Management**
**Important:** Always specify `--rgw-realm`, `--rgw-zonegroup`, and `--rgw-zone` for radosgw-admin commands.

```bash
# Create S3 user
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin user create \
  --uid=myuser \
  --display-name="My User" \
  --rgw-realm=my-store \
  --rgw-zonegroup=my-store \
  --rgw-zone=my-store

# List all users
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin user list \
  --rgw-realm=my-store \
  --rgw-zonegroup=my-store \
  --rgw-zone=my-store

# Get user info (includes access/secret keys)
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- \
  radosgw-admin user info \
  --uid=myuser \
  --rgw-realm=my-store \
  --rgw-zonegroup=my-store \
  --rgw-zone=my-store
```

## 🔍 Troubleshooting

### **Check Cluster Health**
```bash
# Overall cluster status
kubectl get cephcluster -n rook-ceph

# Component status
kubectl get pods -n rook-ceph

# Storage classes
kubectl get storageclass | grep ceph
```

### **Debug Storage Issues**
```bash
# Check PVC status
kubectl get pvc

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Ceph cluster details
kubectl describe cephcluster rook-ceph -n rook-ceph
```

### **Test Results**
```bash
# Check comprehensive test results
kubectl logs -l app=ceph-comprehensive-test --tail=15

# Expected output:
# ✅ Block storage: X lines
# ✅ File storage: X lines (shared)
# ✅ Object storage: S3 API working
```

## 🧹 Cleanup

### **Complete Cleanup**
```bash
# Destroy everything
./scripts/cleanup-all.sh
```

**This removes:**
- ✅ EKS cluster and all resources
- ✅ S3 backend bucket
- ✅ IAM roles and policies
- ✅ GitHub secrets (except GitHub App secrets)
- ✅ Local Terraform state

### **Partial Cleanup (Keep Backend)**
```bash
# Destroy infrastructure only
gh workflow run terraform-destroy.yml -f confirm=destroy
```

## 📚 Technical Details

### **Ceph Components**
- **RADOS:** Reliable Autonomic Distributed Object Store (foundation)
- **RBD:** RADOS Block Device (block storage interface)
- **CephFS:** Ceph File System (POSIX-compliant shared filesystem)
- **RGW:** RADOS Gateway (S3/Swift-compatible object storage)

### **Rook Integration**
- **Custom Resources:** CephCluster, CephBlockPool, CephFilesystem, CephObjectStore
- **CSI Drivers:** Dynamic provisioning for Kubernetes
- **Lifecycle Management:** Automated deployment, scaling, and updates

### **Storage Architecture**
- **Unified Backend:** Single RADOS cluster serves all storage types
- **Dynamic Provisioning:** Kubernetes-native storage allocation
- **Multi-Protocol:** Block, file, and object access to same data pool

## 🌟 Key Benefits

### **Unified Platform**
- Single storage system providing multiple interfaces
- Consistent management and monitoring
- Reduced operational complexity

### **Cloud Native**
- Kubernetes-native deployment and management
- GitOps-compatible configuration
- Container-optimized architecture

### **Cost Effective**
- Open source with no licensing costs
- Commodity hardware support
- Efficient resource utilization

---

## 🚀 Next Steps

This lab provides a foundation for understanding distributed storage systems. To scale for production:

1. **Increase replication** for data redundancy
2. **Add monitoring** with Prometheus and Grafana
3. **Implement backup** strategies for disaster recovery
4. **Tune performance** based on workload requirements

**A complete distributed storage platform ready for real-world applications.** 🎯
