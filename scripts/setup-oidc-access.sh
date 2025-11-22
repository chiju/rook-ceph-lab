#!/bin/bash
set -e

# Get GitHub info from git remote
GIT_REMOTE=$(git remote get-url origin)
GITHUB_REPO=$(echo $GIT_REMOTE | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | cut -d'/' -f2)
GITHUB_ORG=$(echo $GIT_REMOTE | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | cut -d'/' -f1)

ROLE_NAME="GitHubActionsEKSRole"
AWS_PROFILE="oth_infra"

echo "🚀 Setting up AWS OIDC for GitHub Actions..."
echo "Repository: $GITHUB_ORG/$GITHUB_REPO"
echo "AWS Profile: $AWS_PROFILE"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE)
echo "AWS Account ID: $ACCOUNT_ID"

# Check if OIDC provider exists
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC_PROVIDER_ARN --profile $AWS_PROFILE 2>/dev/null; then
  echo "✅ OIDC provider already exists"
else
  echo "Creating OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
    --profile $AWS_PROFILE
  echo "✅ OIDC provider created"
fi

# Create trust policy
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
echo ""
echo "Creating IAM role: $ROLE_NAME..."
if aws iam get-role --role-name $ROLE_NAME --profile $AWS_PROFILE 2>/dev/null; then
  echo "⚠️  Role already exists, updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name $ROLE_NAME \
    --policy-document file:///tmp/trust-policy.json \
    --profile $AWS_PROFILE
else
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --description "GitHub Actions role for EKS GitOps" \
    --profile $AWS_PROFILE
  echo "✅ Role created"
fi

# Attach policies
echo ""
echo "Attaching policies..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile $AWS_PROFILE

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo ""
echo "✅ OIDC setup complete!"
echo ""
echo "📋 Adding GitHub secrets automatically..."

# Add secrets
gh secret set AWS_ROLE_ARN -b "$ROLE_ARN"
gh secret set AWS_ACCOUNT_ID -b "$ACCOUNT_ID"
gh secret set GIT_REPO_URL -b "$GIT_REMOTE"

echo "✅ GitHub secrets added!"
echo ""
echo "⚠️  You still need to add manually:"
echo "gh secret set GIT_USERNAME -b \"$GITHUB_ORG\""
echo "gh secret set ARGOCD_GITHUB_TOKEN -b \"<your-github-pat>\""
echo ""
echo "Role ARN: $ROLE_ARN"
echo ""
echo "🚀 After adding GitHub secrets, push to main to deploy!"
