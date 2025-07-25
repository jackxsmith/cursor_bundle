output "db_instance_address" {
  description = "The RDS instance hostname"
  value       = aws_db_instance.this.address
}

output "db_instance_arn" {
  description = "The RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_instance_availability_zone" {
  description = "The availability zone of the RDS instance"
  value       = aws_db_instance.this.availability_zone
}

output "db_instance_endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_hosted_zone_id" {
  description = "The canonical hosted zone ID of the DB instance (to be used in a Route 53 Alias record)"
  value       = aws_db_instance.this.hosted_zone_id
}

output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.this.id
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.this.resource_id
}

output "db_instance_status" {
  description = "The RDS instance status"
  value       = aws_db_instance.this.status
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "db_instance_port" {
  description = "The database port"
  value       = aws_db_instance.this.port
}

output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.this.id
}

output "db_subnet_group_arn" {
  description = "The ARN of the db subnet group"
  value       = aws_db_subnet_group.this.arn
}

output "db_parameter_group_id" {
  description = "The db parameter group id"
  value       = try(aws_db_parameter_group.this[0].id, null)
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group"
  value       = try(aws_db_parameter_group.this[0].arn, null)
}

output "db_option_group_id" {
  description = "The db option group id"
  value       = try(aws_db_option_group.this[0].id, null)
}

output "db_option_group_arn" {
  description = "The ARN of the db option group"
  value       = try(aws_db_option_group.this[0].arn, null)
}

output "security_group_id" {
  description = "The security group ID"
  value       = aws_security_group.this.id
}

output "security_group_arn" {
  description = "The security group ARN"
  value       = aws_security_group.this.arn
}

output "master_password_secret_arn" {
  description = "The ARN of the master password secret"
  value       = try(aws_secretsmanager_secret.master_password[0].arn, null)
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = var.kms_key_id != null ? var.kms_key_id : try(aws_kms_key.this[0].arn, null)
}

# Convenient outputs
output "endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.this.endpoint
}

output "database_name" {
  description = "The database name"
  value       = aws_db_instance.this.db_name
}