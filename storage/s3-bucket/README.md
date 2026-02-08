# S3 Bucket Module

Creates a secure S3 bucket following AWS security best practices with
encryption, versioning, access logging, and lifecycle rules.

## Features

- **Encryption at rest** - SSE-S3 or SSE-KMS
- **Public access blocked** - All 4 settings enabled
- **Versioning** - Enabled by default
- **Access logging** - Optional to separate bucket
- **Lifecycle rules** - Transition to cheaper storage
- **HTTPS-only policy** - Denies non-TLS access
- **CORS and website** - Optional configurations
- **Replication** - Cross-region/cross-account

## Usage

### Basic Secure Bucket

```hcl
module "s3" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix     = "app-data"
  enable_versioning = true

  lifecycle_rules = {
    "default" = {
      transition_ia_days         = 30
      transition_glacier_days    = 90
      noncurrent_expiration_days = 365
      abort_incomplete_days      = 7
    }
  }

  tags = {
    Environment = "production"
    Application = "my-app"
  }
}
```

### With KMS Encryption

```hcl
module "s3" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix          = "sensitive-data"
  kms_key_arn            = module.kms.key_arn
  require_kms_encryption = true

  tags = {
    DataClassification = "confidential"
  }
}
```

### With Access Logging

```hcl
# Logging bucket
module "logs_bucket" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix     = "access-logs"
  enable_versioning = false

  lifecycle_rules = {
    "expire" = {
      expiration_days = 90
    }
  }
}

# Data bucket with logging
module "data_bucket" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix  = "app-data"
  logging_bucket = module.logs_bucket.bucket_id
}
```

### Static Website

```hcl
module "website" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix = "my-website"

  website_config = {
    index_document = "index.html"
    error_document = "error.html"
  }

  cors_rules = [
    {
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://example.com"]
    }
  ]

  tags = {
    Purpose = "website"
  }
}

# Note: Use CloudFront with OAC for secure website hosting
```

### Cross-Region Replication

```hcl
module "primary" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix     = "primary-data"
  enable_versioning = true  # Required for replication

  replication_config = {
    role_arn               = aws_iam_role.replication.arn
    destination_bucket_arn = "arn:aws:s3:::backup-bucket-us-west-2"
  }

  tags = {
    Environment = "production"
  }
}
```

### With Custom Policy

```hcl
module "shared" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix = "shared-data"

  additional_policy_statements = [
    {
      Sid       = "AllowCrossAccount"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::123456789012:root" }
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resource  = [
        "arn:aws:s3:::shared-data",
        "arn:aws:s3:::shared-data/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "true" }
      }
    }
  ]

  tags = {
    Shared = "true"
  }
}
```

## Using with tf-security

```hcl
module "encryption" {
  source = "github.com/Narcoleptic-Fox/tf-security//aws/encryption"

  name_prefix = "my-app"
  services    = ["s3", "logs"]
}

module "s3" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/s3-bucket"

  bucket_prefix = "secure-data"
  kms_key_arn   = module.encryption.s3_key_arn
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name | Exact bucket name | `string` | `null` | no |
| bucket_prefix | Bucket prefix (account ID prepended) | `string` | `null` | no |
| kms_key_arn | KMS key for encryption | `string` | `null` | no |
| require_kms_encryption | Deny non-KMS uploads | `bool` | `false` | no |
| enable_versioning | Enable versioning | `bool` | `true` | no |
| lifecycle_rules | Lifecycle rules map | `map(object)` | `{}` | no |
| logging_bucket | Logging bucket name | `string` | `null` | no |
| cors_rules | CORS configuration | `list(object)` | `null` | no |
| website_config | Website configuration | `object` | `null` | no |
| replication_config | Replication config | `object` | `null` | no |
| tags | Tags to apply | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | Bucket name |
| bucket_arn | Bucket ARN |
| bucket_domain_name | Bucket domain name |
| bucket_regional_domain_name | Regional domain name |
| bucket_hosted_zone_id | Route 53 zone ID |
| website_endpoint | Website endpoint (if configured) |

## Lifecycle Rule Reference

Common lifecycle configurations:

```hcl
lifecycle_rules = {
  # Standard tiering
  "standard-tiering" = {
    transition_ia_days           = 30
    transition_glacier_ir_days   = 90
    transition_glacier_days      = 180
    transition_deep_archive_days = 365
  }

  # Logs with expiration
  "logs" = {
    prefix          = "logs/"
    expiration_days = 90
  }

  # Noncurrent version cleanup
  "version-cleanup" = {
    noncurrent_transition_ia_days = 30
    noncurrent_expiration_days    = 90
  }

  # Abort incomplete uploads
  "cleanup" = {
    abort_incomplete_days = 7
  }
}
```

## Security Considerations

- ✅ Public access completely blocked
- ✅ HTTPS required (policy denies HTTP)
- ✅ Encryption at rest by default
- ✅ Versioning protects against accidental deletes
- ✅ Bucket ownership enforced (no ACLs)
- ⚠️ Use CMK for sensitive data
- ⚠️ Enable access logging for audit
- ⚠️ Consider Object Lock for compliance
