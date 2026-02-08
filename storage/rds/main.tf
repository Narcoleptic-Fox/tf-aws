/**
 * # RDS Module
 *
 * Creates a secure RDS instance following AWS security best practices.
 *
 * Security features:
 * - Encryption at rest (KMS)
 * - Encryption in transit (SSL)
 * - Multi-AZ for high availability
 * - Automated backups with configurable retention
 * - Performance Insights enabled
 * - Enhanced monitoring
 * - No public accessibility
 * - Deletion protection (production default)
 */

data "aws_caller_identity" "current" {}

locals {
  identifier = var.identifier != null ? var.identifier : "${var.name_prefix}-rds"
  
  # Default parameter group family based on engine
  parameter_group_family = var.parameter_group_family != null ? var.parameter_group_family : (
    var.engine == "postgres" ? "postgres${split(".", var.engine_version)[0]}" :
    var.engine == "mysql" ? "mysql${var.engine_version}" :
    var.engine == "mariadb" ? "mariadb${split(".", var.engine_version)[0]}" :
    null
  )
}

# -----------------------------------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name        = "${local.identifier}-subnet-group"
  description = "Subnet group for ${local.identifier}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${local.identifier}-subnet-group"
  })
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "main" {
  count = var.create_security_group ? 1 : 0

  name        = "${local.identifier}-sg"
  description = "Security group for ${local.identifier}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.identifier}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  count = var.create_security_group ? 1 : 0

  security_group_id = aws_security_group.main[0].id
  description       = "Database access from allowed security groups"

  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.allowed_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "database_cidr" {
  for_each = var.create_security_group ? toset(var.allowed_cidr_blocks) : []

  security_group_id = aws_security_group.main[0].id
  description       = "Database access from CIDR"

  from_port   = var.port
  to_port     = var.port
  ip_protocol = "tcp"
  cidr_ipv4   = each.value
}

# -----------------------------------------------------------------------------
# Parameter Group
# -----------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  count = var.create_parameter_group ? 1 : 0

  name        = "${local.identifier}-params"
  family      = local.parameter_group_family
  description = "Parameter group for ${local.identifier}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  # SSL enforcement parameters
  dynamic "parameter" {
    for_each = var.engine == "postgres" && var.force_ssl ? [1] : []
    content {
      name  = "rds.force_ssl"
      value = "1"
    }
  }

  dynamic "parameter" {
    for_each = var.engine == "mysql" && var.force_ssl ? [1] : []
    content {
      name  = "require_secure_transport"
      value = "ON"
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Option Group (MySQL/MariaDB)
# -----------------------------------------------------------------------------

resource "aws_db_option_group" "main" {
  count = var.create_option_group && contains(["mysql", "mariadb"], var.engine) ? 1 : 0

  name                     = "${local.identifier}-options"
  engine_name              = var.engine
  major_engine_version     = split(".", var.engine_version)[0]
  option_group_description = "Option group for ${local.identifier}"

  dynamic "option" {
    for_each = var.options
    content {
      option_name                    = option.value.option_name
      port                           = lookup(option.value, "port", null)
      version                        = lookup(option.value, "version", null)
      db_security_group_memberships  = lookup(option.value, "db_security_group_memberships", null)
      vpc_security_group_memberships = lookup(option.value, "vpc_security_group_memberships", null)

      dynamic "option_settings" {
        for_each = lookup(option.value, "option_settings", [])
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring
# -----------------------------------------------------------------------------

resource "aws_iam_role" "monitoring" {
  count = var.monitoring_interval > 0 && var.monitoring_role_arn == null ? 1 : 0

  name = "${local.identifier}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.monitoring_interval > 0 && var.monitoring_role_arn == null ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = local.identifier

  # Engine configuration
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type         = var.storage_type
  iops                 = var.iops
  storage_throughput   = var.storage_throughput

  # Database configuration
  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = var.port

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.create_security_group ? [aws_security_group.main[0].id] : var.security_group_ids
  publicly_accessible    = false  # Never public
  network_type           = var.network_type

  # High availability
  multi_az = var.multi_az

  # Security - encryption at rest (always enabled)
  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  # Security - IAM authentication
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # Parameter and option groups
  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.main[0].name : var.parameter_group_name
  option_group_name    = var.create_option_group && contains(["mysql", "mariadb"], var.engine) ? aws_db_option_group.main[0].name : var.option_group_name

  # Backup configuration
  backup_retention_period   = max(var.backup_retention_period, 7)  # Minimum 7 days
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = true
  delete_automated_backups  = var.delete_automated_backups
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.identifier}-final-snapshot"
  skip_final_snapshot       = var.skip_final_snapshot

  # Monitoring
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period
  performance_insights_kms_key_id       = var.performance_insights_kms_key_id
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? (var.monitoring_role_arn != null ? var.monitoring_role_arn : aws_iam_role.monitoring[0].arn) : null
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports

  # Upgrades
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  allow_major_version_upgrade = var.allow_major_version_upgrade
  apply_immediately           = var.apply_immediately

  # Deletion protection (enabled by default for production)
  deletion_protection = var.deletion_protection

  # CA certificate
  ca_cert_identifier = var.ca_cert_identifier

  # License model
  license_model = var.license_model

  tags = merge(var.tags, {
    Name = local.identifier
  })

  depends_on = [
    aws_iam_role_policy_attachment.monitoring
  ]

  lifecycle {
    ignore_changes = [
      password  # Don't track password changes
    ]
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.identifier}-cpu-utilization"
  alarm_description   = "RDS CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "storage" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.identifier}-free-storage-space"
  alarm_description   = "RDS free storage space is too low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.storage_alarm_threshold
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "connections" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.identifier}-database-connections"
  alarm_description   = "RDS database connections are too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.connections_alarm_threshold
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = var.tags
}
