# VPC - isolated network
resource "aws_vpc" "vpc_lrn" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc_lrn"
  }
}

# VPC Flow Logs for network monitoring and security analysis
resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc_lrn.id
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/flowlogs/${var.cluster_name}"
  retention_in_days = 7
}

resource "aws_iam_role" "flow_log_role" {
  name = "${var.cluster_name}-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "${var.cluster_name}-flow-log-policy"
  role = aws_iam_role.flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# VPC Endpoints for private API access (commented for learning)
# Reduces data transfer costs and improves security
# resource "aws_vpc_endpoint" "s3" {
#   vpc_id       = aws_vpc.vpc_lrn.id
#   service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
#   vpc_endpoint_type = "Gateway"
#   route_table_ids = [aws_route_table.private.id]
#
#   tags = {
#     Name = "${var.cluster_name}-s3-endpoint"
#   }
# }

# resource "aws_vpc_endpoint" "ecr_dkr" {
#   vpc_id              = aws_vpc.vpc_lrn.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = [aws_subnet.private_subnet_lrn_1.id, aws_subnet.private_subnet_lrn_2.id]
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#
#   tags = {
#     Name = "${var.cluster_name}-ecr-dkr-endpoint"
#   }
# }

# Security group for VPC endpoints (commented for learning)
# resource "aws_security_group" "vpc_endpoints" {
#   name_prefix = "${var.cluster_name}-vpc-endpoints-"
#   vpc_id      = aws_vpc.vpc_lrn.id
#
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = [var.cidr]
#   }
#
#   tags = {
#     Name = "${var.cluster_name}-vpc-endpoints"
#   }
# }

# Restrict default security group to deny all traffic (security best practice)
# This doesn't affect EKS - cluster uses its own security groups
# Prevents accidental exposure of resources that might use default SG
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc_lrn.id

  # No ingress or egress rules = deny all traffic
  # EKS cluster and nodes use their own specific security groups

  tags = {
    Name = "${var.cluster_name}-default-sg-restricted"
  }
}



# Internet Gateway
resource "aws_internet_gateway" "igw_lrn" {
  vpc_id = aws_vpc.vpc_lrn.id
  tags = {
    Name = "${var.cluster_name}-igw_lrn"
  }
}

# Public Subnets
resource "aws_subnet" "subnet_public_lrn" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.vpc_lrn.id
  cidr_block              = cidrsubnet(var.cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name                                        = "${var.cluster_name}-subnet_public_lrn-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private Subnets
resource "aws_subnet" "subnet_private_lrn" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.vpc_lrn.id
  cidr_block        = cidrsubnet(var.cidr, 4, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-subnet_private_lrn-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"                    = var.cluster_name
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "eip_nat_lrn" {
  domain = "vpc"
  tags = {
    Name = "${var.cluster_name}-eip_nat_lrn"
  }
  depends_on = [aws_internet_gateway.igw_lrn]
}

# NAT Gateway
resource "aws_nat_gateway" "natgw_lrn" {
  allocation_id = aws_eip.eip_nat_lrn.id
  subnet_id     = aws_subnet.subnet_public_lrn[0].id
  tags = {
    Name = "${var.cluster_name}-natgw_lrn"
  }
  depends_on = [aws_internet_gateway.igw_lrn]
}

# Public Route Table
resource "aws_route_table" "rt_public_lrn" {
  vpc_id = aws_vpc.vpc_lrn.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_lrn.id
  }
  tags = {
    Name = "${var.cluster_name}-rt_public_lrn"
  }
}

# Private Route Table (single, shared by both private subnets)
resource "aws_route_table" "rt_private_lrn" {
  vpc_id = aws_vpc.vpc_lrn.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw_lrn.id
  }
  tags = {
    Name = "${var.cluster_name}-rt_private_lrn"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "rta_public_lrn" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.subnet_public_lrn[count.index].id
  route_table_id = aws_route_table.rt_public_lrn.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "rta_private_lrn" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.subnet_private_lrn[count.index].id
  route_table_id = aws_route_table.rt_private_lrn.id
}
