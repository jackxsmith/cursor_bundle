# General Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "6.9.149"
}

variable "git_commit" {
  description = "Git commit hash"
  type        = string
  default     = ""
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
}

variable "elasticache_subnet_cidrs" {
  description = "CIDR blocks for ElastiCache subnets"
  type        = list(string)
  default     = ["10.0.211.0/24", "10.0.212.0/24", "10.0.213.0/24"]
}

variable "intra_subnet_cidrs" {
  description = "CIDR blocks for intra subnets"
  type        = list(string)
  default     = ["10.0.221.0/24", "10.0.222.0/24", "10.0.223.0/24"]
}

# EKS Configuration
variable "eks_node_group_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 3
}

variable "eks_node_group_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1
}

variable "eks_node_group_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 10
}

variable "eks_node_instance_types" {
  description = "List of instance types for EKS node group"
  type        = list(string)
  default     = ["m5.large"]
}

variable "eks_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT"
  type        = string
  default     = "ON_DEMAND"
}

# RDS Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "RDS max allocated storage in GB"
  type        = number
  default     = 100
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

# ElastiCache Configuration
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "elasticache_num_nodes" {
  description = "Number of ElastiCache nodes"
  type        = number
  default     = 1
}

# Application Configuration
variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 3
}

variable "app_resources_requests" {
  description = "Application resource requests"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "250m"
    memory = "256Mi"
  }
}

variable "app_resources_limits" {
  description = "Application resource limits"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

variable "app_environment_variables" {
  description = "Environment variables for the application"
  type        = map(string)
  default = {
    NODE_ENV  = "production"
    LOG_LEVEL = "info"
  }
}

# Domain and SSL Configuration
variable "ingress_domain" {
  description = "Domain name for ingress"
  type        = string
  default     = "cursor-bundle.example.com"
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  type        = string
  default     = ""
}

# Monitoring and Alerting
variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}