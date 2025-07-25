# VPC Module
terraform {
  required_version = ">= 1.5.0"
}

locals {
  max_subnet_length = max(
    length(var.private_subnets),
    length(var.public_subnets),
    length(var.database_subnets),
    length(var.elasticache_subnets),
    length(var.intra_subnets)
  )
  
  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  count = length(var.public_subnets) > 0 ? 1 : 0
  
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-${element(var.azs, count.index)}"
      Type = "public"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(var.azs, count.index)
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-${element(var.azs, count.index)}"
      Type = "private"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# Database Subnets
resource "aws_subnet" "database" {
  count = length(var.database_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = element(var.azs, count.index)
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-database-${element(var.azs, count.index)}"
      Type = "database"
    }
  )
}

# ElastiCache Subnets
resource "aws_subnet" "elasticache" {
  count = length(var.elasticache_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.elasticache_subnets[count.index]
  availability_zone = element(var.azs, count.index)
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-elasticache-${element(var.azs, count.index)}"
      Type = "elasticache"
    }
  )
}

# Intra Subnets (no internet access)
resource "aws_subnet" "intra" {
  count = length(var.intra_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.intra_subnets[count.index]
  availability_zone = element(var.azs, count.index)
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-intra-${element(var.azs, count.index)}"
      Type = "intra"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0
  
  domain = "vpc"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-${count.index + 1}"
    }
  )
  
  depends_on = [aws_internet_gateway.this]
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0
  
  allocation_id = element(aws_eip.nat[*].id, count.index)
  subnet_id     = element(aws_subnet.public[*].id, count.index)
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-${count.index + 1}"
    }
  )
  
  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0
  
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public"
    }
  )
}

# Public Routes
resource "aws_route" "public_internet_gateway" {
  count = length(var.public_subnets) > 0 ? 1 : 0
  
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = local.nat_gateway_count
  
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-${count.index + 1}"
    }
  )
}

# Private Routes
resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0
  
  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)
}

# Database Route Table
resource "aws_route_table" "database" {
  count = length(var.database_subnets) > 0 ? 1 : 0
  
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-database"
    }
  )
}

# ElastiCache Route Table
resource "aws_route_table" "elasticache" {
  count = length(var.elasticache_subnets) > 0 ? 1 : 0
  
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-elasticache"
    }
  )
}

# Intra Route Table
resource "aws_route_table" "intra" {
  count = length(var.intra_subnets) > 0 ? 1 : 0
  
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-intra"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)
  
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)
  
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, var.single_nat_gateway ? 0 : count.index)
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnets)
  
  subnet_id      = element(aws_subnet.database[*].id, count.index)
  route_table_id = aws_route_table.database[0].id
}

resource "aws_route_table_association" "elasticache" {
  count = length(var.elasticache_subnets)
  
  subnet_id      = element(aws_subnet.elasticache[*].id, count.index)
  route_table_id = aws_route_table.elasticache[0].id
}

resource "aws_route_table_association" "intra" {
  count = length(var.intra_subnets)
  
  subnet_id      = element(aws_subnet.intra[*].id, count.index)
  route_table_id = aws_route_table.intra[0].id
}

# VPC Flow Logs
resource "aws_flow_log" "this" {
  count = var.enable_flow_log ? 1 : 0
  
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn
  traffic_type    = var.flow_log_traffic_type
  vpc_id          = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-flow-log"
    }
  )
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_log ? 1 : 0
  
  name              = "/aws/vpc/flowlogs/${var.name}"
  retention_in_days = var.flow_log_retention_days
  
  tags = var.tags
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_log ? 1 : 0
  
  name = "${var.name}-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = var.tags
}

# IAM Role Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_log ? 1 : 0
  
  name = "${var.name}-flow-log-policy"
  role = aws_iam_role.flow_log[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC Endpoints
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0
  
  vpc_id          = aws_vpc.this.id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = concat(
    aws_route_table.private[*].id,
    aws_route_table.public[*].id,
    aws_route_table.database[*].id,
    aws_route_table.elasticache[*].id,
    aws_route_table.intra[*].id
  )
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-s3-endpoint"
    }
  )
}

# Data source for current AWS region
data "aws_region" "current" {}