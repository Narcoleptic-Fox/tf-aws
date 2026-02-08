variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot capacity provider"
  type        = bool
  default     = true
}

variable "fargate_base_count" {
  description = "Base count for Fargate capacity provider strategy"
  type        = number
  default     = 1
}

variable "fargate_weight" {
  description = "Weight for Fargate capacity provider"
  type        = number
  default     = 1
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider"
  type        = number
  default     = 2
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention value."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Service Configuration
# -----------------------------------------------------------------------------

variable "create_service" {
  description = "Create ECS service and task definition"
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID for the service"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs for the service"
  type        = list(string)
  default     = []
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB (for ingress)"
  type        = string
  default     = null
}

variable "target_group_arn" {
  description = "Target group ARN for load balancer integration"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Task Definition
# -----------------------------------------------------------------------------

variable "task_cpu" {
  description = "Task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "Task CPU must be 256, 512, 1024, 2048, or 4096."
  }
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
  default     = 512

  validation {
    condition     = var.task_memory >= 512 && var.task_memory <= 30720
    error_message = "Task memory must be between 512 and 30720 MB."
  }
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Container image to run"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = null
}

variable "container_cpu" {
  description = "CPU units for the container (defaults to task_cpu)"
  type        = number
  default     = null
}

variable "container_memory" {
  description = "Memory for the container in MB (defaults to task_memory)"
  type        = number
  default     = null
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets from Secrets Manager"
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []

  # Example:
  # secrets = [
  #   {
  #     name       = "DB_PASSWORD"
  #     value_from = "arn:aws:secretsmanager:us-east-1:123456789:secret:db-password"
  #   }
  # ]
}

variable "health_check_command" {
  description = "Container health check command"
  type        = string
  default     = null

  # Example: "curl -f http://localhost:8080/health || exit 1"
}

variable "health_check_start_period" {
  description = "Health check start period in seconds"
  type        = number
  default     = 60
}

variable "task_policy_json" {
  description = "Custom IAM policy JSON for the task role"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Service Configuration
# -----------------------------------------------------------------------------

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent during deployment"
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum percent during deployment"
  type        = number
  default     = 200
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 60
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = true
}

variable "enable_deployment_rollback" {
  description = "Enable automatic rollback on deployment failure"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Auto Scaling
# -----------------------------------------------------------------------------

variable "enable_autoscaling" {
  description = "Enable auto scaling for the service"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage"
  type        = number
  default     = 70
}

variable "enable_memory_scaling" {
  description = "Enable memory-based auto scaling"
  type        = bool
  default     = false
}

variable "memory_target_value" {
  description = "Target memory utilization percentage"
  type        = number
  default     = 70
}

variable "scale_in_cooldown" {
  description = "Scale in cooldown in seconds"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Scale out cooldown in seconds"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
