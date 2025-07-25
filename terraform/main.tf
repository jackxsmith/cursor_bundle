terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
  
  backend "s3" {
    bucket                  = "cursor-bundle-terraform-state"
    key                     = "infrastructure/terraform.tfstate"
    region                  = "us-east-1"
    encrypt                 = true
    dynamodb_table          = "cursor-bundle-terraform-locks"
    server_side_encryption_configuration {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }
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
  cluster_version = "1.29"
  
  # Common tags for all resources
  tags = {
    Environment   = var.environment
    Application   = "cursor-bundle"
    Version       = var.app_version
    GitCommit     = var.git_commit
    ManagedBy     = "terraform"
    Owner         = "platform-team"
    BusinessUnit  = "engineering"
    CostCenter    = "engineering-infrastructure"
    BackupPolicy  = var.environment == "production" ? "daily" : "none"
    Compliance    = "pci-dss"
  }
  
  # Environment-specific configurations
  environment_config = {
    production = {
      node_desired_size = 6
      node_min_size     = 3
      node_max_size     = 20
      instance_types    = ["m6i.xlarge", "m6i.2xlarge"]
      capacity_type     = "ON_DEMAND"
      db_instance_class = "db.r6g.xlarge"
      cache_node_type   = "cache.r6g.large"
      backup_retention  = 30
    }
    staging = {
      node_desired_size = 3
      node_min_size     = 1
      node_max_size     = 6
      instance_types    = ["m6i.large", "m6i.xlarge"]
      capacity_type     = "SPOT"
      db_instance_class = "db.t4g.large"
      cache_node_type   = "cache.t4g.medium"
      backup_retention  = 7
    }
    development = {
      node_desired_size = 2
      node_min_size     = 1
      node_max_size     = 3
      instance_types    = ["t3.medium", "t3.large"]
      capacity_type     = "SPOT"
      db_instance_class = "db.t4g.medium"
      cache_node_type   = "cache.t4g.micro"
      backup_retention  = 3
    }
  }
  
  current_config = local.environment_config[var.environment]
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
  
  # Node groups with environment-specific configurations
  eks_managed_node_groups = {
    general = {
      desired_size = local.current_config.node_desired_size
      min_size     = local.current_config.node_min_size
      max_size     = local.current_config.node_max_size
      
      instance_types = local.current_config.instance_types
      capacity_type  = local.current_config.capacity_type
      
      ami_type = "AL2_x86_64"
      disk_size = 100
      
      labels = {
        Environment = var.environment
        NodeGroup   = "general"
        WorkloadType = "application"
      }
      
      taints = []
      
      # Security groups
      vpc_security_group_ids = []
      
      # User data for enhanced security
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        # Enable SSM agent
        yum install -y amazon-ssm-agent
        systemctl enable amazon-ssm-agent
        systemctl start amazon-ssm-agent
        
        # Configure log forwarding
        yum install -y awslogs
        systemctl enable awslogsd
        systemctl start awslogsd
      EOT
      
      # Update strategy
      update_config = {
        max_unavailable_percentage = 25
      }
    }
    
    # Monitoring and system workload node group
    monitoring = {
      desired_size = var.environment == "production" ? 2 : 1
      min_size     = 1
      max_size     = 3
      
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      
      labels = {
        Environment = var.environment
        NodeGroup   = "monitoring"
        WorkloadType = "monitoring"
      }
      
      taints = [{
        key    = "monitoring"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
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
  instance_class = local.current_config.db_instance_class
  
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  
  db_name  = "cursor_bundle"
  username = "cursor_admin"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.database_subnets
  allowed_security_groups = [module.eks.node_security_group_id]
  
  backup_retention_period = local.current_config.backup_retention
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
  
  node_type      = local.current_config.cache_node_type
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

# Security Module
module "security" {
  source = "./modules/security"
  
  cluster_name = module.eks.cluster_name
  vpc_id       = module.vpc.vpc_id
  environment  = var.environment
  
  # Enable security features
  enable_guardduty    = true
  enable_securityhub  = true
  enable_config       = true
  enable_cloudtrail   = true
  enable_inspector    = true
  
  # WAF configuration
  enable_waf = true
  waf_rate_limit = var.environment == "production" ? 2000 : 1000
  
  # KMS encryption
  create_kms_key = true
  kms_key_rotation = true
  
  tags = local.tags
}

# Cost Optimization Module
module "cost_optimization" {
  source = "./modules/cost-optimization"
  
  environment = var.environment
  
  # Auto-scaling configurations
  enable_cluster_autoscaler    = true
  enable_vertical_pod_autoscaler = true
  enable_karpenter            = var.environment == "production"
  
  # Cost monitoring
  enable_cost_anomaly_detection = true
  cost_budget_amount           = var.monthly_budget_limit
  
  # Spot instance configurations
  spot_instance_pools = 3
  on_demand_percentage = var.environment == "production" ? 25 : 10
  
  tags = local.tags
}

# Backup and Disaster Recovery
module "backup" {
  source = "./modules/backup"
  
  environment = var.environment
  
  # EBS snapshots
  enable_ebs_snapshots = true
  snapshot_retention_days = local.current_config.backup_retention
  
  # Cross-region backup for production
  enable_cross_region_backup = var.environment == "production"
  backup_destination_region  = var.backup_region
  
  # RDS automated backups
  rds_instance_id = module.rds.instance_id
  
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
  enable_jaeger     = true
  enable_fluentbit  = true
  
  # Enhanced observability for production
  enable_x_ray              = var.environment == "production"
  enable_container_insights = true
  enable_application_signals = true
  
  # Alerting configuration
  slack_webhook_url = var.slack_webhook_url
  alert_email       = var.alert_email
  pagerduty_integration_key = var.pagerduty_key
  
  # SLA monitoring
  availability_target = var.environment == "production" ? 99.9 : 99.0
  response_time_target = 500 # milliseconds
  
  tags = local.tags
}

# Network Security
module "network_security" {
  source = "./modules/network-security"
  
  vpc_id = module.vpc.vpc_id
  cluster_security_group_id = module.eks.cluster_security_group_id
  
  # Network policies
  enable_network_policies = true
  enable_pod_security_policies = true
  
  # Traffic encryption
  enable_istio_mtls = true
  enable_pod_to_pod_encryption = true
  
  # DDoS protection
  enable_shield_advanced = var.environment == "production"
  
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