output "namespace" {
  description = "ArgoCD namespace"
  value       = var.namespace
}

output "argocd_version" {
  description = "Deployed ArgoCD version"
  value       = helm_release.argocd.version
}
