/**
 * # S3 Bucket Module
 *
 * Creates a secure S3 bucket following AWS security best practices.
 *
 * Security features:
 * - Encryption at rest (SSE-S3 or SSE-KMS)
 * - Public access blocked
 * - Versioning enabled
 * - Access logging
 * - Lifecycle rules
 * - HTTPS-only policy
 */

data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.bucket_name != null ? var.bucket_name : "${data.aws_caller_identity.current.account_id}-${var.bucket_prefix}"
}

# -----------------------------------------------------------------------------
# S3 Bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "main" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = local.bucket_name
  })
}

# -----------------------------------------------------------------------------
# Bucket Ownership Controls
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# -----------------------------------------------------------------------------
# Block Public Access
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Encryption
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null ? true : false
  }
}

# -----------------------------------------------------------------------------
# Versioning
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Suspended"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

# -----------------------------------------------------------------------------
# Lifecycle Rules
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.main.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.key
      status = lookup(rule.value, "enabled", true) ? "Enabled" : "Disabled"

      filter {
        prefix = lookup(rule.value, "prefix", "")
      }

      # Transition to IA
      dynamic "transition" {
        for_each = lookup(rule.value, "transition_ia_days", null) != null ? [1] : []
        content {
          days          = rule.value.transition_ia_days
          storage_class = "STANDARD_IA"
        }
      }

      # Transition to Glacier IR
      dynamic "transition" {
        for_each = lookup(rule.value, "transition_glacier_ir_days", null) != null ? [1] : []
        content {
          days          = rule.value.transition_glacier_ir_days
          storage_class = "GLACIER_IR"
        }
      }

      # Transition to Glacier
      dynamic "transition" {
        for_each = lookup(rule.value, "transition_glacier_days", null) != null ? [1] : []
        content {
          days          = rule.value.transition_glacier_days
          storage_class = "GLACIER"
        }
      }

      # Transition to Deep Archive
      dynamic "transition" {
        for_each = lookup(rule.value, "transition_deep_archive_days", null) != null ? [1] : []
        content {
          days          = rule.value.transition_deep_archive_days
          storage_class = "DEEP_ARCHIVE"
        }
      }

      # Expire current version
      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration_days", null) != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      # Noncurrent version transition
      dynamic "noncurrent_version_transition" {
        for_each = lookup(rule.value, "noncurrent_transition_ia_days", null) != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_transition_ia_days
          storage_class   = "STANDARD_IA"
        }
      }

      # Noncurrent version expiration
      dynamic "noncurrent_version_expiration" {
        for_each = lookup(rule.value, "noncurrent_expiration_days", null) != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_expiration_days
        }
      }

      # Delete incomplete multipart uploads
      dynamic "abort_incomplete_multipart_upload" {
        for_each = lookup(rule.value, "abort_incomplete_days", null) != null ? [1] : []
        content {
          days_after_initiation = rule.value.abort_incomplete_days
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Access Logging
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_logging" "main" {
  count = var.logging_bucket != null ? 1 : 0

  bucket = aws_s3_bucket.main.id

  target_bucket = var.logging_bucket
  target_prefix = var.logging_prefix != null ? var.logging_prefix : "${local.bucket_name}/"
}

# -----------------------------------------------------------------------------
# Bucket Policy
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Always require HTTPS
      [{
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }],
      # Deny if not using KMS encryption (when KMS is configured)
      var.kms_key_arn != null && var.require_kms_encryption ? [{
        Sid       = "DenyIncorrectEncryptionHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.main.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }] : [],
      # Additional statements
      var.additional_policy_statements
    )
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# -----------------------------------------------------------------------------
# CORS Configuration (optional)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_cors_configuration" "main" {
  count = var.cors_rules != null ? 1 : 0

  bucket = aws_s3_bucket.main.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers", ["*"])
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = lookup(cors_rule.value, "expose_headers", [])
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", 3600)
    }
  }
}

# -----------------------------------------------------------------------------
# Website Configuration (optional)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_website_configuration" "main" {
  count = var.website_config != null ? 1 : 0

  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = var.website_config.index_document
  }

  dynamic "error_document" {
    for_each = lookup(var.website_config, "error_document", null) != null ? [1] : []
    content {
      key = var.website_config.error_document
    }
  }
}

# -----------------------------------------------------------------------------
# Replication Configuration (optional)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_replication_configuration" "main" {
  count = var.replication_config != null ? 1 : 0

  bucket = aws_s3_bucket.main.id
  role   = var.replication_config.role_arn

  rule {
    id     = "ReplicateAll"
    status = "Enabled"

    destination {
      bucket        = var.replication_config.destination_bucket_arn
      storage_class = lookup(var.replication_config, "storage_class", "STANDARD")

      dynamic "encryption_configuration" {
        for_each = lookup(var.replication_config, "replica_kms_key_id", null) != null ? [1] : []
        content {
          replica_kms_key_id = var.replication_config.replica_kms_key_id
        }
      }
    }

    dynamic "source_selection_criteria" {
      for_each = var.kms_key_arn != null ? [1] : []
      content {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}
