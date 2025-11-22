#!/bin/bash
set -e

AWS_PROFILE="oth_infra"

echo "🧹 Complete cleanup - deleting everything..."
echo "AWS Profile: $AWS_PROFILE"

# Get info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE 2>/dev/null || echo "")
ROLE_NAME="GitHubActionsEKSRole"
BUCKET_NAME=$(grep 'bucket' terraform/backend.tf | sed 's/.*= *"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
REGION="eu-central-1"

# Get GitHub repo from git remote
GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
GITHUB_REPO=$(echo $GIT_REMOTE | sed 's/.*github.com[:/]\(.*\)\.git/\1/' 2>/dev/null || echo "")

# Delete GitHub secrets (keep GitHub App secrets - they're one-time setup)
if [ -n "$GITHUB_REPO" ]; then
  echo "Deleting GitHub secrets..."
  gh secret delete AWS_ROLE_ARN || true
  gh secret delete AWS_ACCOUNT_ID || true
  gh secret delete GIT_REPO_URL || true
  echo "✅ Keeping GitHub App secrets (ARGOCD_APP_*) - they're reusable"
fi

# Delete IAM role
if [ -n "$ACCOUNT_ID" ]; then
  echo "Deleting IAM role..."
  aws iam detach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
    --profile $AWS_PROFILE 2>/dev/null || true
  aws iam delete-role --role-name $ROLE_NAME --profile $AWS_PROFILE 2>/dev/null || true
fi

# Delete S3 bucket (with all objects and versions)
if [ -n "$BUCKET_NAME" ]; then
  echo "Deleting S3 bucket and all objects..."
  # Delete all versions
  aws s3api delete-objects --bucket $BUCKET_NAME --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --profile $AWS_PROFILE --output json --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" --profile $AWS_PROFILE 2>/dev/null || true
  # Delete all delete markers
  aws s3api delete-objects --bucket $BUCKET_NAME --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --profile $AWS_PROFILE --output json --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" --profile $AWS_PROFILE 2>/dev/null || true
  # Delete bucket
  aws s3api delete-bucket --bucket $BUCKET_NAME --region $REGION --profile $AWS_PROFILE 2>/dev/null || true
fi

# Delete local Terraform state and cache
echo "Cleaning local Terraform files..."
rm -rf terraform/.terraform terraform/.terraform.lock.hcl terraform/terraform.tfstate terraform/terraform.tfstate.backup

echo ""
echo "⚠️  IAM Identity Center cleanup:"
echo "Terraform destroy will handle:"
echo "  - EKS Access Entries"
echo "  - Account assignments"
echo "  - Permission sets"
echo "  - Users"
echo ""
echo "If you want to manually clean Identity Center:"
echo "1. Go to: https://console.aws.amazon.com/singlesignon"
echo "2. Delete users, permission sets, and assignments"
echo "3. Or keep them for future use (no cost)"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "To start fresh, run:"
echo "1. ./scripts/bootstrap-backend.sh"
echo "2. ./scripts/setup-oidc-access.sh"
echo "3. git push origin main"
echo ""
echo "Note: GitHub App secrets (ARGOCD_APP_*) are preserved and will be reused"
