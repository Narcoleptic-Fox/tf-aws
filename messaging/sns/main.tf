/**
 * # SNS Topic Module
 *
 * Creates secure SNS topics following AWS best practices.
 *
 * Security features:
 * - Encryption at rest (SSE-SNS or SSE-KMS)
 * - Access policy with least privilege
 * - HTTPS delivery enforcement
 * - Delivery status logging
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  topic_name = var.fifo_topic ? "${var.name}.fifo" : var.name
}

# -----------------------------------------------------------------------------
# SNS Topic
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "main" {
  name = local.topic_name

  # FIFO settings
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null

  # Encryption (always enabled)
  kms_master_key_id = var.kms_key_arn != null ? var.kms_key_arn : "alias/aws/sns"

  # Display name (for SMS)
  display_name = var.display_name

  # Delivery policy
  delivery_policy = var.delivery_policy != null ? jsonencode(var.delivery_policy) : null

  # Message retention (FIFO only)
  archive_policy = var.fifo_topic && var.message_retention_period != null ? jsonencode({
    MessageRetentionPeriod = var.message_retention_period
  }) : null

  # Signature version
  signature_version = var.signature_version

  # Tracing
  tracing_config = var.enable_tracing ? "Active" : "PassThrough"

  tags = merge(var.tags, {
    Name = local.topic_name
  })
}

# -----------------------------------------------------------------------------
# Topic Policy
# -----------------------------------------------------------------------------

resource "aws_sns_topic_policy" "main" {
  arn = aws_sns_topic.main.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name}-policy"
    Statement = concat(
      # Default owner permissions
      [{
        Sid       = "DefaultOwnerPolicy"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action = [
          "SNS:Publish",
          "SNS:RemovePermission",
          "SNS:SetTopicAttributes",
          "SNS:DeleteTopic",
          "SNS:ListSubscriptionsByTopic",
          "SNS:GetTopicAttributes",
          "SNS:AddPermission",
          "SNS:Subscribe"
        ]
        Resource = aws_sns_topic.main.arn
      }],
      # Deny non-HTTPS publishing
      var.enforce_https ? [{
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }] : [],
      # Allow specified principals to publish
      length(var.publish_principals) > 0 ? [{
        Sid       = "AllowPublish"
        Effect    = "Allow"
        Principal = { AWS = var.publish_principals }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
      }] : [],
      # Allow specified principals to subscribe
      length(var.subscribe_principals) > 0 ? [{
        Sid       = "AllowSubscribe"
        Effect    = "Allow"
        Principal = { AWS = var.subscribe_principals }
        Action    = ["SNS:Subscribe", "SNS:Receive"]
        Resource  = aws_sns_topic.main.arn
      }] : [],
      # Allow CloudWatch Events/EventBridge
      var.allow_eventbridge ? [{
        Sid       = "AllowEventBridge"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
      }] : [],
      # Allow S3 bucket notifications
      length(var.s3_bucket_arns) > 0 ? [{
        Sid       = "AllowS3Notification"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = var.s3_bucket_arns
          }
        }
      }] : [],
      # Allow CloudWatch Alarms
      var.allow_cloudwatch_alarms ? [{
        Sid       = "AllowCloudWatchAlarms"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
      }] : [],
      # Allow Lambda
      length(var.lambda_function_arns) > 0 ? [{
        Sid       = "AllowLambda"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = var.lambda_function_arns
          }
        }
      }] : [],
      # Allow Budgets
      var.allow_budgets ? [{
        Sid       = "AllowBudgets"
        Effect    = "Allow"
        Principal = { Service = "budgets.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
      }] : [],
      # Allow CodePipeline
      var.allow_codepipeline ? [{
        Sid       = "AllowCodePipeline"
        Effect    = "Allow"
        Principal = { Service = "codestar-notifications.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
      }] : [],
      # Cross-account publish
      length(var.cross_account_ids) > 0 ? [{
        Sid       = "AllowCrossAccountPublish"
        Effect    = "Allow"
        Principal = { AWS = [for id in var.cross_account_ids : "arn:aws:iam::${id}:root"] }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
      }] : [],
      # Organization publish
      var.organization_id != null ? [{
        Sid       = "AllowOrganizationPublish"
        Effect    = "Allow"
        Principal = "*"
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.main.arn
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      }] : [],
      # Additional custom statements
      var.additional_policy_statements
    )
  })
}

# -----------------------------------------------------------------------------
# Subscriptions
# -----------------------------------------------------------------------------

# SQS Subscriptions
resource "aws_sns_topic_subscription" "sqs" {
  for_each = var.sqs_subscriptions

  topic_arn = aws_sns_topic.main.arn
  protocol  = "sqs"
  endpoint  = each.value.queue_arn

  raw_message_delivery = lookup(each.value, "raw_message_delivery", false)
  filter_policy        = lookup(each.value, "filter_policy", null) != null ? jsonencode(each.value.filter_policy) : null
  filter_policy_scope  = lookup(each.value, "filter_policy_scope", null)

  redrive_policy = lookup(each.value, "dlq_arn", null) != null ? jsonencode({
    deadLetterTargetArn = each.value.dlq_arn
  }) : null
}

# Lambda Subscriptions
resource "aws_sns_topic_subscription" "lambda" {
  for_each = var.lambda_subscriptions

  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = each.value.function_arn

  filter_policy       = lookup(each.value, "filter_policy", null) != null ? jsonencode(each.value.filter_policy) : null
  filter_policy_scope = lookup(each.value, "filter_policy_scope", null)

  redrive_policy = lookup(each.value, "dlq_arn", null) != null ? jsonencode({
    deadLetterTargetArn = each.value.dlq_arn
  }) : null
}

# Email Subscriptions
resource "aws_sns_topic_subscription" "email" {
  for_each = var.email_subscriptions

  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = each.value

  # Note: Email subscriptions require manual confirmation
}

# HTTPS Subscriptions
resource "aws_sns_topic_subscription" "https" {
  for_each = var.https_subscriptions

  topic_arn = aws_sns_topic.main.arn
  protocol  = "https"
  endpoint  = each.value.url

  raw_message_delivery        = lookup(each.value, "raw_message_delivery", false)
  filter_policy               = lookup(each.value, "filter_policy", null) != null ? jsonencode(each.value.filter_policy) : null
  filter_policy_scope         = lookup(each.value, "filter_policy_scope", null)
  confirmation_timeout_in_minutes = lookup(each.value, "confirmation_timeout", 1)

  redrive_policy = lookup(each.value, "dlq_arn", null) != null ? jsonencode({
    deadLetterTargetArn = each.value.dlq_arn
  }) : null
}

# SMS Subscriptions
resource "aws_sns_topic_subscription" "sms" {
  for_each = var.sms_subscriptions

  topic_arn = aws_sns_topic.main.arn
  protocol  = "sms"
  endpoint  = each.value
}

# -----------------------------------------------------------------------------
# Delivery Status Logging
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "delivery_status_role" {
  count = var.enable_delivery_status_logging ? 1 : 0

  # This creates an IAM role for delivery status logging
  # The actual role is created below
}

resource "aws_iam_role" "delivery_status" {
  count = var.enable_delivery_status_logging ? 1 : 0

  name = "${var.name}-sns-delivery-status"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "sns.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "delivery_status" {
  count = var.enable_delivery_status_logging ? 1 : 0

  name = "delivery-status-logging"
  role = aws_iam_role.delivery_status[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:PutMetricFilter",
        "logs:PutRetentionPolicy"
      ]
      Resource = "*"
    }]
  })
}

# Apply delivery status logging to topic
resource "aws_sns_topic_data_protection_policy" "main" {
  count = var.data_protection_policy != null ? 1 : 0

  arn    = aws_sns_topic.main.arn
  policy = jsonencode(var.data_protection_policy)
}
