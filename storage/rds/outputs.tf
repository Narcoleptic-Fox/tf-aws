output "instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "security_group_id" {
  description = "Security group ID (if created)"
  value       = var.create_security_group ? aws_security_group.main[0].id : null
}

output "subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}

output "parameter_group_name" {
  description = "Parameter group name"
  value       = var.create_parameter_group ? aws_db_parameter_group.main[0].name : var.parameter_group_name
}

output "option_group_name" {
  description = "Option group name (MySQL/MariaDB only)"
  value       = var.create_option_group && contains(["mysql", "mariadb"], var.engine) ? aws_db_option_group.main[0].name : var.option_group_name
}

output "monitoring_role_arn" {
  description = "Enhanced monitoring IAM role ARN"
  value       = var.monitoring_interval > 0 && var.monitoring_role_arn == null ? aws_iam_role.monitoring[0].arn : var.monitoring_role_arn
}

output "availability_zone" {
  description = "Availability zone"
  value       = aws_db_instance.main.availability_zone
}

output "multi_az" {
  description = "Multi-AZ enabled"
  value       = aws_db_instance.main.multi_az
}

output "storage_encrypted" {
  description = "Storage encryption enabled"
  value       = aws_db_instance.main.storage_encrypted
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_db_instance.main.kms_key_id
}

output "resource_id" {
  description = "RDS resource ID (for IAM auth)"
  value       = aws_db_instance.main.resource_id
}

# Connection string outputs for convenience
output "connection_string_postgres" {
  description = "PostgreSQL connection string template"
  value       = var.engine == "postgres" ? "postgresql://${aws_db_instance.main.username}:<password>@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}?sslmode=require" : null
}

output "connection_string_mysql" {
  description = "MySQL connection string template"
  value       = contains(["mysql", "mariadb"], var.engine) ? "mysql://${aws_db_instance.main.username}:<password>@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}?ssl=true" : null
}
