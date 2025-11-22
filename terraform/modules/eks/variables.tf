variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role for EKS access"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for EKS control plane"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_nodes" {
  description = "Desired number of system nodes"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum system nodes for availability"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum system nodes for scaling"
  type        = number
  default     = 3
}
