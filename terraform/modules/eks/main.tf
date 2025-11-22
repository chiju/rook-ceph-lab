# EKS Cluster IAM Role
# KMS Key for EKS Secrets Encryption
# Encrypts Kubernetes secrets at rest in etcd
# resource "aws_kms_key" "eks_secrets" {
#   description             = "KMS key for EKS secrets encryption"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true
#   tags = {
#     Name = "${var.cluster_name}-eks-secrets-key"
#   }
# }

resource "aws_iam_role" "iam_role_eks_lrn" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}

# Attach required policy to cluster role
resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_eks_policy_lrn" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam_role_eks_lrn.name
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster_lrn" {
  name     = var.cluster_name
  role_arn = aws_iam_role.iam_role_eks_lrn.arn
  version  = var.kubernetes_version

  # Enable Access Entries authentication mode
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Encrypt Kubernetes secrets at rest using KMS
  # Protects sensitive data like passwords, tokens, keys
  # encryption_config {
  #   provider {
  #     key_arn = aws_kms_key.eks_secrets.arn
  #   }
  #   resources = ["secrets"]
  # }

  # Enable control plane logging for troubleshooting and security monitoring
  # Logs go to CloudWatch: /aws/eks/{cluster-name}/cluster
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_policy_attachment_eks_policy_lrn
  ]
  tags = {
    Name = var.cluster_name
  }

  # Ensure node groups are deleted before cluster
  lifecycle {
    create_before_destroy = false
  }
}

locals {
  # Convert assumed-role ARN to role ARN
  # From: arn:aws:sts::123:assumed-role/GitHubActionsRole/session
  # To:   arn:aws:iam::123:role/GitHubActionsRole
  executor_arn = replace(
    replace(data.aws_caller_identity.current.arn, ":sts:", ":iam:"),
    ":assumed-role/",
    ":role/"
  )
  # Extract role ARN, handling both assumed-role and user ARNs
  executor_role_arn = try(regex("^(arn:aws:iam::[0-9]+:role/[^/]+)", local.executor_arn)[0], "")
}

# Access entry for your IAM user with built-in admin policy
resource "aws_eks_access_entry" "admin_user" {
  cluster_name  = aws_eks_cluster.eks_cluster_lrn.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/infra_user"
  type          = "STANDARD"
}

# Access entry for the role running Terraform (GitHub Actions)
resource "aws_eks_access_entry" "terraform_executor" {
  count         = var.github_actions_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.eks_cluster_lrn.name
  principal_arn = var.github_actions_role_arn
  type          = "STANDARD"
}

# Use AWS managed policy instead of custom ClusterRoleBinding
resource "aws_eks_access_policy_association" "admin_policy" {
  cluster_name  = aws_eks_cluster.eks_cluster_lrn.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/infra_user"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_user]
}

# Admin policy for Terraform executor
resource "aws_eks_access_policy_association" "terraform_executor_policy" {
  count         = var.github_actions_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.eks_cluster_lrn.name
  principal_arn = var.github_actions_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform_executor]
}

# Wait for access policy to propagate
resource "time_sleep" "wait_for_access_policy" {
  count           = var.github_actions_role_arn != "" ? 1 : 0
  create_duration = "10s"

  depends_on = [aws_eks_access_policy_association.terraform_executor_policy]
}

# EKS Addons - Best practice for managing core components
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eks_cluster_lrn.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.20.4-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.system_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-vpc-cni-addon"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.eks_cluster_lrn.name
  addon_name                  = "coredns"
  addon_version               = "v1.11.3-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.system_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-coredns-addon"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.eks_cluster_lrn.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.34.0-eksbuild.4"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.system_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-kube-proxy-addon"
  }
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = aws_eks_cluster.eks_cluster_lrn.name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.system_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-metrics-server-addon"
  }
}

resource "aws_iam_role" "ebs_csi_role" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.eks_cluster_lrn.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi_role.arn
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.system_nodes
  ]

  tags = {
    Name = "${var.cluster_name}-ebs-csi-addon"
  }
}

# IAM Role for Grafana CloudWatch Access (IRSA)
resource "aws_iam_role" "grafana_cloudwatch_role" {
  name = "${var.cluster_name}-grafana-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:monitoring:monitoring-grafana"
          "${replace(aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer, "https://", "")}:aud" : "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.cluster_name}-grafana-cloudwatch"
  }
}

# Attach CloudWatch permissions to Grafana role
resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Get OIDC provider certificate
data "tls_certificate" "tls_certificate_eks_cluster_lrn" {
  url = aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer
}

# OIDC Provider for IRSA
resource "aws_iam_openid_connect_provider" "iam_openid_connect_provider_eks_cluster_lrn" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tls_certificate_eks_cluster_lrn.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer
  tags = {
    Name = "${var.cluster_name}-oidc-provider"
  }
}

# Node Group IAM Role
resource "aws_iam_role" "iam_role_node_group_lrn" {
  name = "${var.cluster_name}-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  tags = {
    Name = "${var.cluster_name}-node-group-role"
  }
}

# Instance profile for Karpenter nodes
resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "${var.cluster_name}-karpenter-node-profile"
  role = aws_iam_role.iam_role_node_group_lrn.name

  tags = {
    Name = "${var.cluster_name}-karpenter-node-profile"
  }
}

# Attach required policies to node group role
resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_node_group_lrn" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  policy_arn = each.value
  role       = aws_iam_role.iam_role_node_group_lrn.name
}

# System Node Group for cluster stability (Karpenter-ready)
resource "aws_eks_node_group" "system_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster_lrn.name
  node_group_name = "${var.cluster_name}-system-nodes"
  node_role_arn   = aws_iam_role.iam_role_node_group_lrn.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.desired_nodes
    max_size     = var.max_nodes
    min_size     = var.min_nodes
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"

  # Advanced node security via launch template (commented for learning)
  # launch_template {
  #   name    = aws_launch_template.node_security.name
  #   version = aws_launch_template.node_security.latest_version
  # }

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_policy_attachment_node_group_lrn
  ]

  tags = {
    Name = "${var.cluster_name}-system-nodes"
    Type = "system"
  }
}

# Launch template for enhanced node security (commented for learning)
# Provides IMDSv2 enforcement, EBS encryption, and custom configurations
# resource "aws_launch_template" "node_security" {
#   name_prefix   = "${var.cluster_name}-node-security-"
#   image_id      = data.aws_ami.eks_worker.id
#   instance_type = var.node_instance_type
#
#   # Force IMDSv2 to prevent SSRF attacks
#   metadata_options {
#     http_endpoint = "enabled"
#     http_tokens   = "required"  # IMDSv2 only
#     http_put_response_hop_limit = 2
#   }
#
#   # Encrypt EBS volumes for data at rest protection
#   block_device_mappings {
#     device_name = "/dev/xvda"
#     ebs {
#       volume_size = 20
#       volume_type = "gp3"
#       encrypted   = true
#       delete_on_termination = true
#     }
#   }
#
#   # Custom security group for nodes
#   vpc_security_group_ids = [aws_security_group.node_security.id]
#
#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name = "${var.cluster_name}-worker-node"
#       Environment = "production"
#     }
#   }
# }

# Custom security group for enhanced node security (commented for learning)
# resource "aws_security_group" "node_security" {
#   name_prefix = "${var.cluster_name}-node-security-"
#   vpc_id      = var.vpc_id
#
#   # Allow cluster communication
#   ingress {
#     from_port   = 1025
#     to_port     = 65535
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc_cidr]
#   }
#
#   # Allow HTTPS outbound
#   egress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "${var.cluster_name}-node-security"
#   }
# }

# Tag cluster security group for Karpenter discovery
resource "aws_ec2_tag" "cluster_sg_karpenter" {
  resource_id = aws_eks_cluster.eks_cluster_lrn.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# EC2 Spot service-linked role is automatically created by AWS when needed
# No need to manage it in Terraform

# Karpenter IAM Role
resource "aws_iam_role" "karpenter_controller" {
  name = "KarpenterControllerRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:karpenter"
          "${replace(aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "karpenter_controller" {
  name = "KarpenterControllerPolicy-${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.eks_cluster_lrn.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.iam_role_node_group_lrn.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:TagInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteLaunchTemplate"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# Karpenter SQS Queue for Spot interruption handling
resource "aws_sqs_queue" "karpenter" {
  name                      = var.cluster_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter" {
  queue_url = aws_sqs_queue.karpenter.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "events.amazonaws.com",
          "sqs.amazonaws.com"
        ]
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.karpenter.arn
    }]
  })
}

# EventBridge rules for Spot interruptions
resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${var.cluster_name}-spot-interruption"
  description = "Karpenter Spot Instance Interruption Warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  target_id = "KarpenterSpotInterruptionQueue"
  arn       = aws_sqs_queue.karpenter.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${var.cluster_name}-rebalance"
  description = "Karpenter EC2 Instance Rebalance Recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "KarpenterRebalanceQueue"
  arn       = aws_sqs_queue.karpenter.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name        = "${var.cluster_name}-instance-state-change"
  description = "Karpenter EC2 Instance State-change Notification"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  target_id = "KarpenterInstanceStateChangeQueue"
  arn       = aws_sqs_queue.karpenter.arn
}

# ACK EKS Controller IRSA Role
resource "aws_iam_role" "ack_eks_controller_role" {
  name = "${var.cluster_name}-ack-eks-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.iam_openid_connect_provider_eks_cluster_lrn.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:ack-system:ack-eks-controller"
          "${replace(aws_eks_cluster.eks_cluster_lrn.identity[0].oidc[0].issuer, "https://", "")}:aud" : "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.cluster_name}-ack-eks-controller-role"
  }
}

# ACK EKS Controller Policy
resource "aws_iam_role_policy" "ack_eks_controller_policy" {
  name = "${var.cluster_name}-ack-eks-controller-policy"
  role = aws_iam_role.ack_eks_controller_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:DescribeAccessEntry",
          "eks:ListAccessEntries",
          "eks:UpdateAccessEntry",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
          "eks:ListAssociatedAccessPolicies",
          "eks:TagResource",
          "eks:UntagResource"
        ]
        Resource = [
          aws_eks_cluster.eks_cluster_lrn.arn,
          "arn:aws:eks:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:access-entry/${var.cluster_name}/*/*"
        ]
      }
    ]
  })
}

