variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "users" {
  description = "Identity Center users to create"
  type = map(object({
    email        = string
    given_name   = string
    family_name  = string
    display_name = string
  }))
}

variable "permission_sets" {
  description = "Permission sets to create"
  type = map(object({
    description        = string
    managed_policy_arn = string
  }))
}

variable "user_assignments" {
  description = "User to permission set assignments"
  type = map(object({
    user           = string
    permission_set = string
  }))
}

