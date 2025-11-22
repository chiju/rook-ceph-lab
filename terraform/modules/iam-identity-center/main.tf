data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get Identity Center instance
data "aws_ssoadmin_instances" "main" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  account_id        = data.aws_caller_identity.current.account_id
}

# Create Identity Center users
resource "aws_identitystore_user" "users" {
  for_each = var.users

  identity_store_id = local.identity_store_id
  display_name      = each.value.display_name
  user_name         = each.key

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    primary = true
  }
}

# Create permission sets
resource "aws_ssoadmin_permission_set" "sets" {
  for_each = var.permission_sets

  name             = each.key
  description      = each.value.description
  instance_arn     = local.instance_arn
  session_duration = "PT4H"
}

# Attach managed policies to permission sets
resource "aws_ssoadmin_managed_policy_attachment" "policies" {
  for_each = var.permission_sets

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sets[each.key].arn
  managed_policy_arn = each.value.managed_policy_arn
}

# Assign users to permission sets
resource "aws_ssoadmin_account_assignment" "assignments" {
  for_each = var.user_assignments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sets[each.value.permission_set].arn

  principal_id   = aws_identitystore_user.users[each.value.user].user_id
  principal_type = "USER"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

# NOTE: SSO roles are provisioned by AWS asynchronously (2-3 minutes)
# ACK controller will create access entries from CRDs in ArgoCD
# No need to query SSO roles here

