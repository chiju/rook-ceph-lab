#!/bin/bash
set -e

# Variables
BUCKET_NAME="eks-gitops-tfstate-$(openssl rand -hex 4)"
REGION="eu-central-1"
AWS_PROFILE="oth_infra"

echo "🚀 Bootstrapping Terraform backend..."
echo "S3 Bucket: $BUCKET_NAME"
echo "Region: $REGION"
echo "AWS Profile: $AWS_PROFILE"

# Create S3 bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION \
  --profile $AWS_PROFILE

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled \
  --profile $AWS_PROFILE

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --profile $AWS_PROFILE

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile $AWS_PROFILE

echo "✅ Backend created successfully!"
echo ""

# Auto-update backend.tf
BACKEND_FILE="terraform/backend.tf"
cat > $BACKEND_FILE <<EOF
# S3 backend with native state locking (no DynamoDB needed)
# For GitHub Actions with OIDC - no profile needed
terraform {
  backend "s3" {
    bucket       = "$BUCKET_NAME"
    key          = "eks-gitops-lab.tfstate"
    region       = "$REGION"
    encrypt      = true
    use_lockfile = true
  }
}
EOF

echo "✅ Updated $BACKEND_FILE automatically!"
echo ""
echo "Backend configuration:"
cat $BACKEND_FILE
