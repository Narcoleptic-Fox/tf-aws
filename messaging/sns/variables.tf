variable "name" {
  description = "Topic name (without .fifo suffix)"
  type        = string
}

variable "display_name" {
  description = "Display name for SMS subscriptions"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# FIFO Settings
# -----------------------------------------------------------------------------

variable "fifo_topic" {
  description = "Create a FIFO topic"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication (FIFO only)"
  type        = bool
  default     = true
}

variable "message_retention_period" {
  description = "Message retention in seconds for FIFO topics"
  type        = number
  default     = null
}

# -----------------------------------------------------------------------------
# Encryption
# -----------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "KMS key ARN (uses aws/sns if not specified)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Delivery Settings
# -----------------------------------------------------------------------------

variable "delivery_policy" {
  description = "Delivery policy for HTTP/S endpoints"
  type        = any
  default     = null
}

variable "signature_version" {
  description = "Signature version for delivery (1 or 2)"
  type        = string
  default     = "2"
}

variable "enable_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Access Policy
# -----------------------------------------------------------------------------

variable "enforce_https" {
  description = "Deny non-HTTPS publish requests"
  type        = bool
  default     = true
}

variable "publish_principals" {
  description = "AWS principals (ARNs) allowed to publish"
  type        = list(string)
  default     = []
}

variable "subscribe_principals" {
  description = "AWS principals (ARNs) allowed to subscribe"
  type        = list(string)
  default     = []
}

variable "allow_eventbridge" {
  description = "Allow EventBridge to publish"
  type        = bool
  default     = false
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs allowed to publish notifications"
  type        = list(string)
  default     = []
}

variable "allow_cloudwatch_alarms" {
  description = "Allow CloudWatch Alarms to publish"
  type        = bool
  default     = false
}

variable "lambda_function_arns" {
  description = "Lambda function ARNs allowed to publish"
  type        = list(string)
  default     = []
}

variable "allow_budgets" {
  description = "Allow AWS Budgets to publish"
  type        = bool
  default     = false
}

variable "allow_codepipeline" {
  description = "Allow CodePipeline/CodeStar notifications"
  type        = bool
  default     = false
}

variable "cross_account_ids" {
  description = "AWS account IDs allowed to publish"
  type        = list(string)
  default     = []
}

variable "organization_id" {
  description = "Organization ID allowed to publish"
  type        = string
  default     = null
}

variable "additional_policy_statements" {
  description = "Additional IAM policy statements"
  type        = list(any)
  default     = []
}

# -----------------------------------------------------------------------------
# Subscriptions
# -----------------------------------------------------------------------------

variable "sqs_subscriptions" {
  description = "SQS queue subscriptions"
  type = map(object({
    queue_arn            = string
    raw_message_delivery = optional(bool, false)
    filter_policy        = optional(any)
    filter_policy_scope  = optional(string)
    dlq_arn              = optional(string)
  }))
  default = {}
}

variable "lambda_subscriptions" {
  description = "Lambda function subscriptions"
  type = map(object({
    function_arn        = string
    filter_policy       = optional(any)
    filter_policy_scope = optional(string)
    dlq_arn             = optional(string)
  }))
  default = {}
}

variable "email_subscriptions" {
  description = "Email subscriptions (map of name to email)"
  type        = map(string)
  default     = {}
}

variable "https_subscriptions" {
  description = "HTTPS endpoint subscriptions"
  type = map(object({
    url                  = string
    raw_message_delivery = optional(bool, false)
    filter_policy        = optional(any)
    filter_policy_scope  = optional(string)
    confirmation_timeout = optional(number, 1)
    dlq_arn              = optional(string)
  }))
  default = {}
}

variable "sms_subscriptions" {
  description = "SMS subscriptions (map of name to phone number)"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "enable_delivery_status_logging" {
  description = "Enable delivery status logging to CloudWatch"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Data Protection
# -----------------------------------------------------------------------------

variable "data_protection_policy" {
  description = "Data protection policy for PII detection"
  type        = any
  default     = null
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
