# RDS Module
terraform {
  required_version = ">= 1.5.0"
}

# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-subnet-group"
    }
  )
}

# DB Parameter Group
resource "aws_db_parameter_group" "this" {
  count = var.create_db_parameter_group ? 1 : 0

  name   = "${var.identifier}-pg"
  family = var.db_parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = try(parameter.value.apply_method, "immediate")
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-parameter-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# DB Option Group
resource "aws_db_option_group" "this" {
  count = var.create_db_option_group ? 1 : 0

  name                     = "${var.identifier}-og"
  option_group_description = "Option group for ${var.identifier}"
  engine_name              = var.engine
  major_engine_version     = var.major_engine_version

  dynamic "option" {
    for_each = var.options
    content {
      option_name                    = option.value.option_name
      port                          = try(option.value.port, null)
      version                       = try(option.value.version, null)
      db_security_group_memberships = try(option.value.db_security_group_memberships, null)
      vpc_security_group_memberships = try(option.value.vpc_security_group_memberships, null)

      dynamic "option_settings" {
        for_each = try(option.value.option_settings, [])
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-option-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for RDS
resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier} RDS instance"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-sg"
    }
  )
}

resource "aws_security_group_rule" "ingress" {
  for_each = toset(var.allowed_security_groups)

  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.this.id
}

resource "aws_security_group_rule" "cidr_ingress" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.this.id
}

# KMS Key for RDS encryption
resource "aws_kms_key" "this" {
  count = var.kms_key_id == null ? 1 : 0

  description             = "KMS key for ${var.identifier} RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-rds-key"
    }
  )
}

resource "aws_kms_alias" "this" {
  count = var.kms_key_id == null ? 1 : 0

  name          = "alias/${var.identifier}-rds"
  target_key_id = aws_kms_key.this[0].key_id
}

# Random password for master user
resource "random_password" "master_password" {
  count = var.manage_master_user_password ? 1 : 0

  length  = 16
  special = true
}

# AWS Secrets Manager secret for master password
resource "aws_secretsmanager_secret" "master_password" {
  count = var.manage_master_user_password ? 1 : 0

  name        = "${var.identifier}-master-password"
  description = "Master password for ${var.identifier} RDS instance"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "master_password" {
  count = var.manage_master_user_password ? 1 : 0

  secret_id = aws_secretsmanager_secret.master_password[0].id
  secret_string = jsonencode({
    username = var.username
    password = random_password.master_password[0].result
  })
}

# RDS Instance
resource "aws_db_instance" "this" {
  identifier = var.identifier

  # Engine options
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.kms_key_id != null ? var.kms_key_id : try(aws_kms_key.this[0].arn, null)

  # Database
  db_name  = var.db_name
  username = var.username
  password = var.manage_master_user_password ? null : var.password
  port     = var.port

  # Master user password management
  manage_master_user_password   = var.manage_master_user_password
  master_user_secret_kms_key_id = var.manage_master_user_password ? try(aws_kms_key.this[0].arn, null) : null

  # Network & Security
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = var.publicly_accessible

  # Parameter and option groups
  parameter_group_name = var.create_db_parameter_group ? aws_db_parameter_group.this[0].name : var.parameter_group_name
  option_group_name    = var.create_db_option_group ? aws_db_option_group.this[0].name : var.option_group_name

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  copy_tags_to_snapshot  = var.copy_tags_to_snapshot
  delete_automated_backups = var.delete_automated_backups

  # Maintenance
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id      = var.performance_insights_enabled ? try(aws_kms_key.this[0].arn, null) : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Deletion protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Multi-AZ
  multi_az = var.multi_az

  # Storage IOPS
  iops = var.iops

  tags = var.tags

  depends_on = [
    aws_db_subnet_group.this,
    aws_security_group.this
  ]
}

# Enhanced monitoring IAM role
resource "aws_iam_role" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.identifier}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}