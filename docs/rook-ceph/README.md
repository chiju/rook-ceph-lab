# Rook Ceph Storage Integration

Distributed storage cluster using Rook Ceph operator, deployed via GitOps in the EKS cluster.

## 🚀 Deployment

```bash
export AWS_PROFILE=oth_infra

# Applications will auto-deploy via ArgoCD
# Monitor deployment status
kubectl -n argocd get applications | grep -E "(rook|ceph)"
```

## 📊 Components Deployed

### Rook Operator (`apps/rook-operator/`)
- **Chart**: `rook-ceph` v1.18.7 from `https://charts.rook.io/release`
- **Namespace**: `rook-ceph`
- **Features**: Discovery daemon, RBD/CephFS CSI drivers

### Ceph Cluster (`apps/ceph-cluster/`)
- **MON**: 3 monitors for consensus
- **MGR**: 2 managers with dashboard
- **OSD**: 3 OSDs using EBS volumes (`/dev/nvme1n1`)
- **Replication**: 3x for high availability

### Storage Classes (`apps/ceph-storage-classes/`)
- **RBD Block Storage**: `rook-ceph-block` storage class
- **Test App**: Sample deployment with PVC
- **Features**: Dynamic provisioning, volume expansion

## 🔧 Monitoring Commands

```bash
# Check ArgoCD sync status
kubectl -n argocd get app rook-operator ceph-cluster ceph-storage-classes

# Monitor Rook pods
kubectl -n rook-ceph get pods -w

# Check Ceph cluster health
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# View Ceph dashboard (port-forward)
kubectl -n rook-ceph port-forward svc/rook-ceph-mgr-dashboard 8443:8443

# Check storage classes
kubectl get storageclass | grep ceph

# Monitor test PVC
kubectl get pvc ceph-test-pvc
kubectl describe pvc ceph-test-pvc
```

## 🎯 Learning Areas

### Ceph Architecture
- **MON (Monitors)**: Cluster state and consensus
- **OSD (Object Storage Daemons)**: Data storage and replication
- **MGR (Managers)**: Cluster management and metrics
- **CRUSH Map**: Data placement algorithm

### Rook Operator
- **CRDs**: CephCluster, CephBlockPool, CephObjectStore
- **CSI Integration**: Dynamic volume provisioning
- **Lifecycle Management**: Automated deployment and scaling

### Storage Operations
- **Block Storage**: RBD volumes for pods
- **Replication**: 3x data copies across nodes
- **Failure Domains**: Host-level fault tolerance

## 🚨 Troubleshooting

```bash
# Check operator logs
kubectl -n rook-ceph logs -l app=rook-ceph-operator

# Check OSD status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree

# Check cluster events
kubectl -n rook-ceph get events --sort-by='.lastTimestamp'

# Verify storage devices
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- lsblk
```

---

**Status**: Deployed via ArgoCD GitOps  
**Profile**: `export AWS_PROFILE=oth_infra`
