variable "function_name" {
  description = "Name of the Lambda function"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", var.function_name))
    error_message = "Function name must start with a letter and contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Deployment Package
# -----------------------------------------------------------------------------

variable "filename" {
  description = "Path to the deployment package (zip file)"
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the deployment package"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "S3 object version of the deployment package"
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI for container-based Lambda"
  type        = string
  default     = null
}

variable "image_config" {
  description = "Container image configuration"
  type = object({
    command           = optional(list(string))
    entry_point       = optional(list(string))
    working_directory = optional(string)
  })
  default = null
}

# -----------------------------------------------------------------------------
# Runtime Settings
# -----------------------------------------------------------------------------

variable "handler" {
  description = "Function handler (e.g., index.handler)"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda runtime (e.g., nodejs20.x, python3.12)"
  type        = string
  default     = "nodejs20.x"

  validation {
    condition = contains([
      "nodejs18.x", "nodejs20.x",
      "python3.9", "python3.10", "python3.11", "python3.12",
      "java17", "java21",
      "dotnet6", "dotnet8",
      "ruby3.2", "ruby3.3",
      "provided.al2", "provided.al2023"
    ], var.runtime)
    error_message = "Must be a valid Lambda runtime."
  }
}

variable "architecture" {
  description = "CPU architecture (x86_64 or arm64)"
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "Architecture must be x86_64 or arm64."
  }
}

variable "layers" {
  description = "List of Lambda layer ARNs"
  type        = list(string)
  default     = []
}

variable "timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "memory_size" {
  description = "Memory size in MB"
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory must be between 128 and 10240 MB."
  }
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in MB"
  type        = number
  default     = 512

  validation {
    condition     = var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240
    error_message = "Ephemeral storage must be between 512 and 10240 MB."
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions (-1 for no limit)"
  type        = number
  default     = -1
}

variable "publish" {
  description = "Publish a new version on each update"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs to grant access"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------

variable "vpc_config" {
  description = "VPC configuration for the function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null

  # Example:
  # vpc_config = {
  #   subnet_ids         = ["subnet-123", "subnet-456"]
  #   security_group_ids = ["sg-789"]
  # }
}

# -----------------------------------------------------------------------------
# Observability
# -----------------------------------------------------------------------------

variable "tracing_mode" {
  description = "X-Ray tracing mode (Active or PassThrough)"
  type        = string
  default     = "PassThrough"

  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "Tracing mode must be Active or PassThrough."
  }
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
  description = "KMS key ARN for log and environment encryption"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Dead Letter Queue
# -----------------------------------------------------------------------------

variable "dead_letter_target_arn" {
  description = "ARN of the dead letter queue (SQS) or topic (SNS)"
  type        = string
  default     = null
}

variable "dead_letter_target_type" {
  description = "Type of dead letter target (sqs or sns)"
  type        = string
  default     = "sqs"

  validation {
    condition     = contains(["sqs", "sns"], var.dead_letter_target_type)
    error_message = "Dead letter target type must be sqs or sns."
  }
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------

variable "policy_json" {
  description = "Custom IAM policy JSON"
  type        = string
  default     = null
}

variable "additional_policy_arns" {
  description = "Additional managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Function URL
# -----------------------------------------------------------------------------

variable "create_function_url" {
  description = "Create a Lambda function URL"
  type        = bool
  default     = false
}

variable "function_url_auth_type" {
  description = "Function URL authorization type"
  type        = string
  default     = "AWS_IAM"

  validation {
    condition     = contains(["AWS_IAM", "NONE"], var.function_url_auth_type)
    error_message = "Auth type must be AWS_IAM or NONE."
  }
}

variable "function_url_cors" {
  description = "CORS configuration for function URL"
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), ["*"])
    allow_methods     = optional(list(string), ["*"])
    allow_origins     = optional(list(string), ["*"])
    expose_headers    = optional(list(string), [])
    max_age           = optional(number, 0)
  })
  default = null
}

# -----------------------------------------------------------------------------
# Alias
# -----------------------------------------------------------------------------

variable "create_alias" {
  description = "Create a Lambda alias"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Name of the alias"
  type        = string
  default     = "live"
}

variable "alias_description" {
  description = "Description of the alias"
  type        = string
  default     = null
}

variable "alias_version" {
  description = "Function version for the alias (defaults to latest)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Event Sources
# -----------------------------------------------------------------------------

variable "event_source_mappings" {
  description = "Map of event source mappings (SQS, DynamoDB, Kinesis)"
  type = map(object({
    event_source_arn                   = string
    enabled                            = optional(bool, true)
    batch_size                         = optional(number)
    maximum_batching_window_in_seconds = optional(number)
    starting_position                  = optional(string)
    starting_position_timestamp        = optional(string)
    filter_patterns                    = optional(list(string))
  }))
  default = {}

  # Example:
  # event_source_mappings = {
  #   "sqs" = {
  #     event_source_arn = "arn:aws:sqs:us-east-1:123456789:my-queue"
  #     batch_size       = 10
  #   }
  # }
}

# -----------------------------------------------------------------------------
# Permissions
# -----------------------------------------------------------------------------

variable "permissions" {
  description = "Map of Lambda permissions for other services"
  type = map(object({
    principal      = string
    source_arn     = optional(string)
    source_account = optional(string)
    action         = optional(string)
  }))
  default = {}

  # Example:
  # permissions = {
  #   "api_gateway" = {
  #     principal  = "apigateway.amazonaws.com"
  #     source_arn = "arn:aws:execute-api:us-east-1:123456789:api-id/*"
  #   }
  # }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
