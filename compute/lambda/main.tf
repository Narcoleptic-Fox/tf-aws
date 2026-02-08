/**
 * # Lambda Module
 *
 * Creates a Lambda function with CloudWatch Logs integration,
 * optional VPC attachment, and environment variables.
 *
 * Features:
 * - Multiple deployment options (zip, S3, ECR image)
 * - VPC attachment for private resources
 * - Environment variables and secrets
 * - X-Ray tracing
 * - Dead letter queue support
 * - Function URL (optional)
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group (created before Lambda)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name        = "${var.function_name}-role"
  description = "Execution role for Lambda function ${var.function_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# Basic execution (CloudWatch Logs)
resource "aws_iam_role_policy" "logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
    }]
  })
}

# VPC access
resource "aws_iam_role_policy_attachment" "vpc" {
  count = var.vpc_config != null ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing
resource "aws_iam_role_policy_attachment" "xray" {
  count = var.tracing_mode == "Active" ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Secrets Manager access
resource "aws_iam_role_policy" "secrets" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  name = "secrets-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.secret_arns
    }]
  })
}

# KMS access for secrets
resource "aws_iam_role_policy" "kms" {
  count = var.kms_key_arn != null ? 1 : 0

  name = "kms-decrypt"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      Resource = [var.kms_key_arn]
    }]
  })
}

# Dead letter queue
resource "aws_iam_role_policy" "dlq" {
  count = var.dead_letter_target_arn != null ? 1 : 0

  name = "dead-letter-queue"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = var.dead_letter_target_type == "sns" ? ["sns:Publish"] : ["sqs:SendMessage"]
      Resource = [var.dead_letter_target_arn]
    }]
  })
}

# Custom policy
resource "aws_iam_role_policy" "custom" {
  count = var.policy_json != null ? 1 : 0

  name   = "custom-permissions"
  role   = aws_iam_role.lambda.id
  policy = var.policy_json
}

# Additional managed policies
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.lambda.name
  policy_arn = each.value
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "main" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.lambda.arn

  # Deployment package (one of: filename, s3, or image)
  filename         = var.filename
  source_code_hash = var.source_code_hash
  s3_bucket        = var.s3_bucket
  s3_key           = var.s3_key
  s3_object_version = var.s3_object_version
  image_uri        = var.image_uri
  package_type     = var.image_uri != null ? "Image" : "Zip"

  # Runtime settings (for zip packages)
  handler     = var.image_uri == null ? var.handler : null
  runtime     = var.image_uri == null ? var.runtime : null
  layers      = var.image_uri == null ? var.layers : null

  # For container images
  dynamic "image_config" {
    for_each = var.image_config != null ? [var.image_config] : []
    content {
      command           = lookup(image_config.value, "command", null)
      entry_point       = lookup(image_config.value, "entry_point", null)
      working_directory = lookup(image_config.value, "working_directory", null)
    }
  }

  architectures = [var.architecture]
  timeout       = var.timeout
  memory_size   = var.memory_size

  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                        = var.publish

  # Environment variables
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # Tracing
  tracing_config {
    mode = var.tracing_mode
  }

  # Dead letter queue
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  # Ephemeral storage
  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.logs
  ]
}

# -----------------------------------------------------------------------------
# Function URL (optional)
# -----------------------------------------------------------------------------

resource "aws_lambda_function_url" "main" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.main.function_name
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_credentials = lookup(cors.value, "allow_credentials", false)
      allow_headers     = lookup(cors.value, "allow_headers", ["*"])
      allow_methods     = lookup(cors.value, "allow_methods", ["*"])
      allow_origins     = lookup(cors.value, "allow_origins", ["*"])
      expose_headers    = lookup(cors.value, "expose_headers", [])
      max_age           = lookup(cors.value, "max_age", 0)
    }
  }
}

# -----------------------------------------------------------------------------
# Lambda Alias (optional)
# -----------------------------------------------------------------------------

resource "aws_lambda_alias" "main" {
  count = var.create_alias ? 1 : 0

  name             = var.alias_name
  description      = var.alias_description
  function_name    = aws_lambda_function.main.function_name
  function_version = var.alias_version != null ? var.alias_version : aws_lambda_function.main.version
}

# -----------------------------------------------------------------------------
# Event Source Mappings (optional)
# -----------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "main" {
  for_each = var.event_source_mappings

  event_source_arn = each.value.event_source_arn
  function_name    = aws_lambda_function.main.arn

  enabled                            = lookup(each.value, "enabled", true)
  batch_size                         = lookup(each.value, "batch_size", null)
  maximum_batching_window_in_seconds = lookup(each.value, "maximum_batching_window_in_seconds", null)
  starting_position                  = lookup(each.value, "starting_position", null)
  starting_position_timestamp        = lookup(each.value, "starting_position_timestamp", null)

  dynamic "filter_criteria" {
    for_each = lookup(each.value, "filter_patterns", null) != null ? [1] : []
    content {
      dynamic "filter" {
        for_each = each.value.filter_patterns
        content {
          pattern = filter.value
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Permissions (optional - for invoking from other services)
# -----------------------------------------------------------------------------

resource "aws_lambda_permission" "main" {
  for_each = var.permissions

  statement_id   = each.key
  action         = lookup(each.value, "action", "lambda:InvokeFunction")
  function_name  = aws_lambda_function.main.function_name
  principal      = each.value.principal
  source_arn     = lookup(each.value, "source_arn", null)
  source_account = lookup(each.value, "source_account", null)
}
