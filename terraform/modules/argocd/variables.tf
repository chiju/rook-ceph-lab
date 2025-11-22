variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.0.5"
}

variable "git_repo_url" {
  description = "Git repository URL"
  type        = string
}

variable "git_target_revision" {
  description = "Git branch/tag"
  type        = string
  default     = "main"
}

variable "git_apps_path" {
  description = "Path to ArgoCD applications in repo"
  type        = string
  default     = "argocd-apps"
}

variable "github_app_id" {
  description = "GitHub App ID"
  type        = string
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
}

variable "github_app_private_key" {
  description = "GitHub App Private Key"
  type        = string
  sensitive   = true
}

variable "enable_ha" {
  description = "Enable high availability mode (2 replicas for controller, server, repo-server)"
  type        = bool
  default     = false
}
