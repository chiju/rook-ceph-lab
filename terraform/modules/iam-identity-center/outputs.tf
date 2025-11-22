output "users_created" {
  description = "Identity Center users created"
  value       = keys(aws_identitystore_user.users)
}

output "permission_sets_created" {
  description = "Permission sets created"
  value       = keys(aws_ssoadmin_permission_set.sets)
}

output "access_portal_url" {
  description = "AWS access portal URL for SSO login"
  value       = "https://${split("/", local.instance_arn)[1]}.awsapps.com/start"
}

output "setup_instructions" {
  description = "Next steps for users"
  value       = <<-EOT
  ✅ Identity Center Setup Complete!
  
  Users created: ${join(", ", keys(aws_identitystore_user.users))}
  
  📧 Check emails for invitation links:
  ${join("\n  ", [for k, v in var.users : "- ${v.email}"])}
  
  🔐 After setting passwords, configure AWS CLI:
  
  aws configure sso
  SSO start URL: https://${split("/", local.instance_arn)[1]}.awsapps.com/start
  SSO region: ${data.aws_region.current.id}
  
  ⚠️  Wait 3 minutes for AWS to provision SSO roles
  ⚠️  Access entries will be created by ACK controller from ArgoCD!
  
  Check: kubectl get accessentry -A
  
  Then login and access EKS:
  aws sso login --profile <profile-name>
  aws eks update-kubeconfig --name ${var.cluster_name} --profile <profile-name>
  EOT
}

