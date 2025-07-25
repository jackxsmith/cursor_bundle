terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
  
  backend "s3" {
    bucket         = "cursor-bundle-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cursor-bundle-terraform-locks"
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "CursorBundle"
      Version     = var.app_version
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local variables
locals {
  name            = "cursor-bundle-${var.environment}"
  cluster_version = "1.28"
  
  tags = {
    Environment = var.environment
    Application = "cursor-bundle"
    Version     = var.app_version
    GitCommit   = var.git_commit
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  name                 = local.name
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.private_subnet_cidrs
  public_subnets       = var.public_subnet_cidrs
  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "production"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = local.tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = local.name
  cluster_version = local.cluster_version
  
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets
  
  # Node groups
  eks_managed_node_groups = {
    general = {
      desired_size = var.eks_node_group_desired_size
      min_size     = var.eks_node_group_min_size
      max_size     = var.eks_node_group_max_size
      
      instance_types = var.eks_node_instance_types
      capacity_type  = var.eks_capacity_type
      
      labels = {
        Environment = var.environment
        NodeGroup   = "general"
      }
      
      taints = []
    }
  }
  
  # Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  
  tags = local.tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  identifier = "${local.name}-db"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.rds_instance_class
  
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  
  db_name  = "cursor_bundle"
  username = "cursor_admin"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.database_subnets
  allowed_security_groups = [module.eks.node_security_group_id]
  
  backup_retention_period = var.rds_backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  deletion_protection = var.environment == "production"
  skip_final_snapshot = var.environment != "production"
  
  tags = local.tags
}

# ElastiCache Module
module "elasticache" {
  source = "./modules/elasticache"
  
  name = local.name
  
  node_type      = var.elasticache_node_type
  num_cache_nodes = var.elasticache_num_nodes
  engine_version  = "7.0"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.elasticache_subnets
  allowed_security_groups = [module.eks.node_security_group_id]
  
  snapshot_retention_limit = var.environment == "production" ? 7 : 1
  
  tags = local.tags
}

# S3 Buckets
module "s3_buckets" {
  source = "./modules/s3"
  
  environment = var.environment
  name_prefix = local.name
  
  create_logging_bucket = true
  create_backup_bucket  = true
  create_assets_bucket  = true
  
  versioning_enabled = var.environment == "production"
  
  tags = local.tags
}

# Application deployment
module "cursor_bundle_app" {
  source = "./modules/cursor-bundle-app"
  
  cluster_name        = module.eks.cluster_name
  namespace          = "cursor-bundle"
  app_version        = var.app_version
  
  database_host      = module.rds.endpoint
  database_name      = module.rds.database_name
  database_secret_arn = module.rds.master_password_secret_arn
  
  redis_endpoint     = module.elasticache.primary_endpoint
  
  s3_assets_bucket   = module.s3_buckets.assets_bucket_name
  s3_logging_bucket  = module.s3_buckets.logging_bucket_name
  
  ingress_domain     = var.ingress_domain
  certificate_arn    = var.acm_certificate_arn
  
  replicas           = var.app_replicas
  resources_requests = var.app_resources_requests
  resources_limits   = var.app_resources_limits
  
  environment_variables = var.app_environment_variables
  
  tags = local.tags
}

# Monitoring and Alerting
module "monitoring" {
  source = "./modules/monitoring"
  
  cluster_name = module.eks.cluster_name
  namespace    = "monitoring"
  
  enable_prometheus = true
  enable_grafana    = true
  enable_loki       = true
  
  slack_webhook_url = var.slack_webhook_url
  alert_email       = var.alert_email
  
  tags = local.tags
}

# Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.primary_endpoint
  sensitive   = true
}

output "app_url" {
  description = "Application URL"
  value       = "https://${var.ingress_domain}"
}

output "monitoring_url" {
  description = "Grafana URL"
  value       = "https://grafana.${var.ingress_domain}"
}