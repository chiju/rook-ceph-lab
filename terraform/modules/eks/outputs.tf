output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.eks_cluster_lrn.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.eks_cluster_lrn.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.eks_cluster_lrn.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.eks_cluster_lrn.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.arn
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.system_nodes.id
}

output "grafana_cloudwatch_role_arn" {
  description = "IAM role ARN for Grafana CloudWatch access"
  value       = aws_iam_role.grafana_cloudwatch_role.arn
}


output "node_instance_profile_name" {
  description = "Instance profile name for EKS nodes"
  value       = aws_eks_node_group.system_nodes.resources[0].remote_access_security_group_id != "" ? split("/", aws_iam_role.iam_role_node_group_lrn.arn)[1] : aws_iam_role.iam_role_node_group_lrn.name
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = aws_iam_instance_profile.karpenter_node_instance_profile.name
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for Karpenter controller"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_name" {
  description = "IAM role name for Karpenter nodes"
  value       = aws_iam_role.iam_role_node_group_lrn.name
}

output "karpenter_sqs_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter.name
}

output "ack_eks_controller_role_arn" {
  description = "IAM role ARN for ACK EKS controller"
  value       = aws_iam_role.ack_eks_controller_role.arn
}

