#!/bin/bash
set -e

CLUSTER_NAME="eks-gitops-lab"
REGION="eu-central-1"

echo "🔐 Setting up RBAC users for EKS cluster..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IAM users
echo "📝 Creating IAM users..."
aws iam create-user --user-name charlie-dev 2>/dev/null || echo "  charlie-dev already exists"
aws iam create-user --user-name bob-devops 2>/dev/null || echo "  bob-devops already exists"
aws iam create-user --user-name diana-viewer 2>/dev/null || echo "  diana-viewer already exists"

# Create access keys
echo "🔑 Creating access keys..."
echo ""
echo "Charlie (Developer):"
aws iam create-access-key --user-name charlie-dev 2>/dev/null || echo "  Access key already exists"
echo ""
echo "Bob (DevOps):"
aws iam create-access-key --user-name bob-devops 2>/dev/null || echo "  Access key already exists"
echo ""
echo "Diana (Viewer):"
aws iam create-access-key --user-name diana-viewer 2>/dev/null || echo "  Access key already exists"

# Map to EKS with K8s groups
echo ""
echo "🔗 Mapping IAM users to Kubernetes groups..."

# Charlie → developers group
aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --principal-arn arn:aws:iam::${ACCOUNT_ID}:user/charlie-dev \
  --type STANDARD \
  --kubernetes-groups developers \
  --region $REGION 2>/dev/null && echo "  ✅ charlie-dev → developers" || echo "  charlie-dev already mapped"

# Bob → devops group
aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --principal-arn arn:aws:iam::${ACCOUNT_ID}:user/bob-devops \
  --type STANDARD \
  --kubernetes-groups devops \
  --region $REGION 2>/dev/null && echo "  ✅ bob-devops → devops" || echo "  bob-devops already mapped"

# Diana → viewers group
aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --principal-arn arn:aws:iam::${ACCOUNT_ID}:user/diana-viewer \
  --type STANDARD \
  --kubernetes-groups viewers \
  --region $REGION 2>/dev/null && echo "  ✅ diana-viewer → viewers" || echo "  diana-viewer already mapped"

echo ""
echo "✅ RBAC setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Save the access keys above"
echo "2. Configure AWS CLI profiles:"
echo ""
echo "   aws configure --profile charlie-dev"
echo "   aws configure --profile bob-devops"
echo "   aws configure --profile diana-viewer"
echo ""
echo "3. Test access:"
echo ""
echo "   aws eks update-kubeconfig --name $CLUSTER_NAME --profile charlie-dev --region $REGION"
echo "   kubectl get pods -n dev"
