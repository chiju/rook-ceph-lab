#!/bin/bash
set -e

AWS_PROFILE="oth_infra"
REGION="eu-central-1"

echo "🔐 Setting up IAM Identity Center users..."

# Get Identity Center instance
INSTANCE_ARN=$(aws sso-admin list-instances --profile $AWS_PROFILE --region $REGION --query 'Instances[0].InstanceArn' --output text)
IDENTITY_STORE_ID=$(aws sso-admin list-instances --profile $AWS_PROFILE --region $REGION --query 'Instances[0].IdentityStoreId' --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)

echo "Instance ARN: $INSTANCE_ARN"
echo "Identity Store ID: $IDENTITY_STORE_ID"
echo "Account ID: $ACCOUNT_ID"

# Get email
read -p "Enter your email prefix (e.g., 'chijuar' for chijuar+alice@gmail.com): " EMAIL_PREFIX
EMAIL_DOMAIN="gmail.com"

# Create users
echo ""
echo "Creating users..."
for USER in alice bob charlie; do
  EMAIL="${EMAIL_PREFIX}+${USER}@${EMAIL_DOMAIN}"
  echo "Creating user: $USER ($EMAIL)"
  
  aws identitystore create-user \
    --identity-store-id $IDENTITY_STORE_ID \
    --user-name "${USER}-user" \
    --display-name "$(echo $USER | sed 's/.*/\u&/') User" \
    --name GivenName="$(echo $USER | sed 's/.*/\u&/')",FamilyName="User" \
    --emails Value=$EMAIL,Primary=true \
    --profile $AWS_PROFILE \
    --region $REGION || echo "User $USER may already exist"
done

# Create permission sets
echo ""
echo "Creating permission sets..."

# Admin
aws sso-admin create-permission-set \
  --instance-arn $INSTANCE_ARN \
  --name "EKSAdmin" \
  --description "Full EKS admin access" \
  --session-duration "PT4H" \
  --profile $AWS_PROFILE \
  --region $REGION || echo "EKSAdmin may already exist"

ADMIN_PS_ARN=$(aws sso-admin list-permission-sets --instance-arn $INSTANCE_ARN --profile $AWS_PROFILE --region $REGION --query "PermissionSets[?contains(@, 'EKSAdmin')]" --output text)

aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn $INSTANCE_ARN \
  --permission-set-arn $ADMIN_PS_ARN \
  --managed-policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" \
  --profile $AWS_PROFILE \
  --region $REGION || true

# Developer
aws sso-admin create-permission-set \
  --instance-arn $INSTANCE_ARN \
  --name "EKSDeveloper" \
  --description "EKS developer access" \
  --session-duration "PT4H" \
  --profile $AWS_PROFILE \
  --region $REGION || echo "EKSDeveloper may already exist"

DEV_PS_ARN=$(aws sso-admin list-permission-sets --instance-arn $INSTANCE_ARN --profile $AWS_PROFILE --region $REGION --query "PermissionSets[?contains(@, 'EKSDeveloper')]" --output text)

aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn $INSTANCE_ARN \
  --permission-set-arn $DEV_PS_ARN \
  --managed-policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess" \
  --profile $AWS_PROFILE \
  --region $REGION || true

# ReadOnly
aws sso-admin create-permission-set \
  --instance-arn $INSTANCE_ARN \
  --name "EKSReadOnly" \
  --description "EKS read-only access" \
  --session-duration "PT4H" \
  --profile $AWS_PROFILE \
  --region $REGION || echo "EKSReadOnly may already exist"

READONLY_PS_ARN=$(aws sso-admin list-permission-sets --instance-arn $INSTANCE_ARN --profile $AWS_PROFILE --region $REGION --query "PermissionSets[?contains(@, 'EKSReadOnly')]" --output text)

aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn $INSTANCE_ARN \
  --permission-set-arn $READONLY_PS_ARN \
  --managed-policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess" \
  --profile $AWS_PROFILE \
  --region $REGION || true

# Assign users to permission sets
echo ""
echo "Assigning users to permission sets..."

# Get user IDs
ALICE_ID=$(aws identitystore list-users --identity-store-id $IDENTITY_STORE_ID --profile $AWS_PROFILE --region $REGION --query "Users[?UserName=='alice-user'].UserId" --output text)
BOB_ID=$(aws identitystore list-users --identity-store-id $IDENTITY_STORE_ID --profile $AWS_PROFILE --region $REGION --query "Users[?UserName=='bob-user'].UserId" --output text)
CHARLIE_ID=$(aws identitystore list-users --identity-store-id $IDENTITY_STORE_ID --profile $AWS_PROFILE --region $REGION --query "Users[?UserName=='charlie-user'].UserId" --output text)

# Alice -> Admin
aws sso-admin create-account-assignment \
  --instance-arn $INSTANCE_ARN \
  --target-id $ACCOUNT_ID \
  --target-type AWS_ACCOUNT \
  --permission-set-arn $ADMIN_PS_ARN \
  --principal-type USER \
  --principal-id $ALICE_ID \
  --profile $AWS_PROFILE \
  --region $REGION || true

# Bob -> Developer
aws sso-admin create-account-assignment \
  --instance-arn $INSTANCE_ARN \
  --target-id $ACCOUNT_ID \
  --target-type AWS_ACCOUNT \
  --permission-set-arn $DEV_PS_ARN \
  --principal-type USER \
  --principal-id $BOB_ID \
  --profile $AWS_PROFILE \
  --region $REGION || true

# Charlie -> ReadOnly
aws sso-admin create-account-assignment \
  --instance-arn $INSTANCE_ARN \
  --target-id $ACCOUNT_ID \
  --target-type AWS_ACCOUNT \
  --permission-set-arn $READONLY_PS_ARN \
  --principal-type USER \
  --principal-id $CHARLIE_ID \
  --profile $AWS_PROFILE \
  --region $REGION || true

echo ""
echo "✅ Identity Center setup complete!"
echo ""
echo "Next steps:"
echo "1. Check your email and verify the 3 users"
echo "2. Wait 2 minutes for AWS to create SSO roles"
echo "3. Run Terraform to add EKS access entries"
