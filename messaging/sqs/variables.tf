variable "name" {
  description = "Queue name (without .fifo suffix)"
  type        = string
}

# -----------------------------------------------------------------------------
# FIFO Settings
# -----------------------------------------------------------------------------

variable "fifo_queue" {
  description = "Create a FIFO queue"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication (FIFO only)"
  type        = bool
  default     = true
}

variable "deduplication_scope" {
  description = "Deduplication scope (messageGroup or queue)"
  type        = string
  default     = "queue"

  validation {
    condition     = contains(["messageGroup", "queue"], var.deduplication_scope)
    error_message = "Deduplication scope must be messageGroup or queue."
  }
}

variable "fifo_throughput_limit" {
  description = "FIFO throughput limit (perQueue or perMessageGroupId)"
  type        = string
  default     = "perQueue"

  validation {
    condition     = contains(["perQueue", "perMessageGroupId"], var.fifo_throughput_limit)
    error_message = "FIFO throughput limit must be perQueue or perMessageGroupId."
  }
}

# -----------------------------------------------------------------------------
# Message Settings
# -----------------------------------------------------------------------------

variable "delay_seconds" {
  description = "Delay in seconds for message delivery (0-900)"
  type        = number
  default     = 0

  validation {
    condition     = var.delay_seconds >= 0 && var.delay_seconds <= 900
    error_message = "Delay must be between 0 and 900 seconds."
  }
}

variable "max_message_size" {
  description = "Maximum message size in bytes (1024-262144)"
  type        = number
  default     = 262144

  validation {
    condition     = var.max_message_size >= 1024 && var.max_message_size <= 262144
    error_message = "Max message size must be between 1024 and 262144 bytes."
  }
}

variable "message_retention_seconds" {
  description = "Message retention period (60-1209600 seconds)"
  type        = number
  default     = 345600  # 4 days

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "Message retention must be between 60 and 1209600 seconds."
  }
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time (0-20 seconds)"
  type        = number
  default     = 20  # Enable long polling by default

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "Receive wait time must be between 0 and 20 seconds."
  }
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout (0-43200 seconds)"
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "Visibility timeout must be between 0 and 43200 seconds."
  }
}

# -----------------------------------------------------------------------------
# Encryption
# -----------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (uses SQS managed key if not specified)"
  type        = string
  default     = null
}

variable "kms_data_key_reuse_period" {
  description = "KMS data key reuse period in seconds (60-86400)"
  type        = number
  default     = 300

  validation {
    condition     = var.kms_data_key_reuse_period >= 60 && var.kms_data_key_reuse_period <= 86400
    error_message = "KMS data key reuse period must be between 60 and 86400 seconds."
  }
}

# -----------------------------------------------------------------------------
# Dead Letter Queue
# -----------------------------------------------------------------------------

variable "create_dlq" {
  description = "Create a dead-letter queue"
  type        = bool
  default     = true
}

variable "dlq_arn" {
  description = "ARN of existing DLQ (if not creating one)"
  type        = string
  default     = null
}

variable "max_receive_count" {
  description = "Number of receives before sending to DLQ"
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "Message retention for DLQ (longer for debugging)"
  type        = number
  default     = 1209600  # 14 days (max)
}

# -----------------------------------------------------------------------------
# Access Policy
# -----------------------------------------------------------------------------

variable "create_queue_policy" {
  description = "Create a queue access policy"
  type        = bool
  default     = true
}

variable "send_message_principals" {
  description = "AWS principals (ARNs) allowed to send messages"
  type        = list(string)
  default     = []
}

variable "receive_message_principals" {
  description = "AWS principals (ARNs) allowed to receive messages"
  type        = list(string)
  default     = []
}

variable "sns_topic_arns" {
  description = "SNS topic ARNs allowed to publish to this queue"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs allowed to send notifications"
  type        = list(string)
  default     = []
}

variable "allow_eventbridge" {
  description = "Allow EventBridge to send messages"
  type        = bool
  default     = false
}

variable "additional_policy_statements" {
  description = "Additional IAM policy statements"
  type        = list(any)
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

variable "dlq_alarm_threshold" {
  description = "Alarm when DLQ has more than N messages"
  type        = number
  default     = 1
}

variable "oldest_message_alarm_threshold" {
  description = "Alarm when oldest message is older than N seconds"
  type        = number
  default     = null
}

variable "queue_depth_alarm_threshold" {
  description = "Alarm when queue has more than N messages"
  type        = number
  default     = null
}

variable "alarm_actions" {
  description = "SNS topic ARNs for alarm actions"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
