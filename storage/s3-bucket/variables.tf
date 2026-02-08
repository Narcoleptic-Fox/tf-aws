variable "bucket_name" {
  description = "Exact bucket name (mutually exclusive with bucket_prefix)"
  type        = string
  default     = null
}

variable "bucket_prefix" {
  description = "Bucket name prefix (account ID will be prepended)"
  type        = string
  default     = null

  validation {
    condition     = var.bucket_prefix == null || can(regex("^[a-z0-9][a-z0-9.-]*$", var.bucket_prefix))
    error_message = "Bucket prefix must start with letter/number and contain only lowercase letters, numbers, periods, and hyphens."
  }
}

variable "force_destroy" {
  description = "Force destroy bucket even if it contains objects"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Encryption
# -----------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS encryption (uses SSE-S3 if null)"
  type        = string
  default     = null
}

variable "require_kms_encryption" {
  description = "Deny uploads that don't use KMS encryption"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Versioning
# -----------------------------------------------------------------------------

variable "enable_versioning" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete (requires root credentials)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Lifecycle Rules
# -----------------------------------------------------------------------------

variable "lifecycle_rules" {
  description = "Map of lifecycle rules"
  type = map(object({
    enabled                       = optional(bool, true)
    prefix                        = optional(string, "")
    transition_ia_days            = optional(number)
    transition_glacier_ir_days    = optional(number)
    transition_glacier_days       = optional(number)
    transition_deep_archive_days  = optional(number)
    expiration_days               = optional(number)
    noncurrent_transition_ia_days = optional(number)
    noncurrent_expiration_days    = optional(number)
    abort_incomplete_days         = optional(number)
  }))
  default = {}

  # Example:
  # lifecycle_rules = {
  #   "default" = {
  #     transition_ia_days         = 30
  #     transition_glacier_days    = 90
  #     noncurrent_expiration_days = 365
  #     abort_incomplete_days      = 7
  #   }
  # }
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "logging_bucket" {
  description = "S3 bucket for access logs"
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for access logs (defaults to bucket name)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Bucket Policy
# -----------------------------------------------------------------------------

variable "additional_policy_statements" {
  description = "Additional bucket policy statements"
  type        = list(any)
  default     = []

  # Example:
  # additional_policy_statements = [
  #   {
  #     Sid       = "AllowCrossAccount"
  #     Effect    = "Allow"
  #     Principal = { AWS = "arn:aws:iam::123456789:root" }
  #     Action    = ["s3:GetObject"]
  #     Resource  = "${aws_s3_bucket.main.arn}/*"
  #   }
  # ]
}

# -----------------------------------------------------------------------------
# CORS
# -----------------------------------------------------------------------------

variable "cors_rules" {
  description = "List of CORS rules"
  type = list(object({
    allowed_headers = optional(list(string), ["*"])
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3600)
  }))
  default = null

  # Example:
  # cors_rules = [
  #   {
  #     allowed_methods = ["GET", "HEAD"]
  #     allowed_origins = ["https://example.com"]
  #   }
  # ]
}

# -----------------------------------------------------------------------------
# Website
# -----------------------------------------------------------------------------

variable "website_config" {
  description = "Static website hosting configuration"
  type = object({
    index_document = string
    error_document = optional(string)
  })
  default = null

  # Example:
  # website_config = {
  #   index_document = "index.html"
  #   error_document = "error.html"
  # }
}

# -----------------------------------------------------------------------------
# Replication
# -----------------------------------------------------------------------------

variable "replication_config" {
  description = "Cross-region replication configuration"
  type = object({
    role_arn               = string
    destination_bucket_arn = string
    storage_class          = optional(string, "STANDARD")
    replica_kms_key_id     = optional(string)
  })
  default = null

  # Example:
  # replication_config = {
  #   role_arn               = "arn:aws:iam::123456789:role/s3-replication"
  #   destination_bucket_arn = "arn:aws:s3:::backup-bucket"
  # }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
