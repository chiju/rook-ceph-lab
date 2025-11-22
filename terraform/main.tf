# EKS Lab with ArgoCD - Main Configuration
# Deployed via GitHub Actions with OIDC authentication
# Updated: 2025-11-22 17:01 - Deploy minimal Rook Ceph cluster

# Account ID validation
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# Prevent running against wrong account
resource "null_resource" "account_validation" {
  count = local.account_id != var.allowed_account_id ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: Terraform is running against account ${local.account_id} but only ${var.allowed_account_id} is allowed' && exit 1"
  }
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name       = var.cluster_name
  cidr               = var.cidr
  availability_zones = var.availability_zones

  depends_on = [null_resource.account_validation]
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  github_actions_role_arn = var.github_actions_role_arn
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_instance_type      = var.node_instance_type
  desired_nodes           = var.desired_nodes
  min_nodes               = var.min_nodes
  max_nodes               = var.max_nodes

  depends_on = [module.vpc, null_resource.account_validation]
}

# ArgoCD module - Using GitHub App for authentication
module "argocd" {
  source = "./modules/argocd"

  namespace           = "argocd"
  argocd_version      = "9.1.0"
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision
  git_apps_path       = "argocd-apps"

  # GitHub App authentication
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key

  depends_on = [module.eks, null_resource.account_validation]
}

# IAM Identity Center Integration - Disabled for clean Rook Ceph deployment
# module "iam_identity_center" {
#   source = "./modules/iam-identity-center"
#
#   cluster_name = var.cluster_name
#
#   # Users
#   users = {
#     alice-dev = {
#       email        = "chijuar@gmail.com"
#       given_name   = "Alice"
#       family_name  = "Developer"
#       display_name = "Alice Developer"
#     }
#     bob-devops = {
#       email        = "chijumel@gmail.com"
#       given_name   = "Bob"
#       family_name  = "DevOps"
#       display_name = "Bob DevOps"
#     }
#     diana-viewer = {
#       email        = "chijumelveettil@gmail.com"
#       given_name   = "Diana"
#       family_name  = "Viewer"
#       display_name = "Diana Viewer"
#     }
#     akhila-devops = {
#       email        = "akhilachiju@gmail.com"
#       given_name   = "Akhila"
#       family_name  = "Chandran"
#       display_name = "Akhila Chandran"
#     }
#   }
#
#   # Permission sets
#   permission_sets = {
#     EKSDeveloper = {
#       description        = "EKS Developer access"
#       managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
#     }
#     EKSDevOps = {
#       description        = "EKS DevOps access"
#       managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
#     }
#     EKSReadOnly = {
#       description        = "EKS read-only access"
#       managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
#     }
#   }
#
#   # User assignments
#   user_assignments = {
#     alice-to-developer = {
#       user           = "alice-dev"
#       permission_set = "EKSDeveloper"
#     }
#     bob-to-devops = {
#       user           = "bob-devops"
#       permission_set = "EKSDevOps"
#     }
#     diana-to-viewer = {
#       user           = "diana-viewer"
#       permission_set = "EKSReadOnly"
#     }
#     akhila-to-devops = {
#       user           = "akhila-devops"
#       permission_set = "EKSDevOps"
#     }
#   }
#
#   # NOTE: Access entries will be created by ACK controller from ArgoCD
#   # See: apps/access-entries/ for CRD definitions
#
#   # No depends_on needed - Identity Center users are independent of EKS
# }
