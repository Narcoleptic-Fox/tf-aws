variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "identifier" {
  description = "RDS instance identifier (overrides name_prefix-rds)"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets required for RDS subnet group."
  }
}

# -----------------------------------------------------------------------------
# Engine Configuration
# -----------------------------------------------------------------------------

variable "engine" {
  description = "Database engine (postgres, mysql, mariadb)"
  type        = string

  validation {
    condition     = contains(["postgres", "mysql", "mariadb"], var.engine)
    error_message = "Engine must be postgres, mysql, or mariadb."
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling (0 to disable)"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "iops" {
  description = "Provisioned IOPS (for io1/io2/gp3)"
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "Storage throughput in MiBps (gp3 only)"
  type        = number
  default     = null
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = null
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "password" {
  description = "Master password (use secrets manager in production)"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Database port"
  type        = number
  default     = null
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "create_security_group" {
  description = "Create a security group for the RDS instance"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "List of security group IDs (if not creating)"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_id" {
  description = "Security group ID allowed to access the database"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the database"
  type        = list(string)
  default     = []
}

variable "network_type" {
  description = "Network type (IPV4 or DUAL)"
  type        = string
  default     = "IPV4"
}

# -----------------------------------------------------------------------------
# High Availability
# -----------------------------------------------------------------------------

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------

variable "kms_key_id" {
  description = "KMS key ARN for encryption (uses AWS managed key if not specified)"
  type        = string
  default     = null
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = true
}

variable "force_ssl" {
  description = "Force SSL connections (via parameter group)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Parameter and Option Groups
# -----------------------------------------------------------------------------

variable "create_parameter_group" {
  description = "Create a parameter group"
  type        = bool
  default     = true
}

variable "parameter_group_name" {
  description = "Existing parameter group name"
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "Parameter group family (auto-detected if not specified)"
  type        = string
  default     = null
}

variable "parameters" {
  description = "List of DB parameters"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "create_option_group" {
  description = "Create an option group (MySQL/MariaDB only)"
  type        = bool
  default     = false
}

variable "option_group_name" {
  description = "Existing option group name"
  type        = string
  default     = null
}

variable "options" {
  description = "List of DB options"
  type        = any
  default     = []
}

# -----------------------------------------------------------------------------
# Backup Configuration
# -----------------------------------------------------------------------------

variable "backup_retention_period" {
  description = "Backup retention period (minimum 7 days enforced)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "delete_automated_backups" {
  description = "Delete automated backups on instance deletion"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Monitoring
# -----------------------------------------------------------------------------

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period (7 or 731 days)"
  type        = number
  default     = 7
}

variable "performance_insights_kms_key_id" {
  description = "KMS key for Performance Insights"
  type        = string
  default     = null
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
}

variable "monitoring_role_arn" {
  description = "ARN of the monitoring role (created if not specified)"
  type        = string
  default     = null
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

variable "create_cloudwatch_alarms" {
  description = "Create CloudWatch alarms"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "storage_alarm_threshold" {
  description = "Free storage space alarm threshold (bytes)"
  type        = number
  default     = 5368709120  # 5 GB
}

variable "connections_alarm_threshold" {
  description = "Database connections alarm threshold"
  type        = number
  default     = 100
}

variable "alarm_actions" {
  description = "List of ARNs for alarm actions (SNS topics)"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Upgrades
# -----------------------------------------------------------------------------

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "allow_major_version_upgrade" {
  description = "Allow major version upgrades"
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Protection
# -----------------------------------------------------------------------------

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Other
# -----------------------------------------------------------------------------

variable "ca_cert_identifier" {
  description = "CA certificate identifier"
  type        = string
  default     = null
}

variable "license_model" {
  description = "License model"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
