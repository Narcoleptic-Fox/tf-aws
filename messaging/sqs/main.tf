/**
 * # SQS Queue Module
 *
 * Creates secure SQS queues following AWS best practices.
 *
 * Security features:
 * - Encryption at rest (SSE-SQS or SSE-KMS)
 * - Dead-letter queue support
 * - Access policy with least privilege
 * - VPC endpoint ready
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  queue_name     = var.fifo_queue ? "${var.name}.fifo" : var.name
  dlq_queue_name = var.fifo_queue ? "${var.name}-dlq.fifo" : "${var.name}-dlq"
}

# -----------------------------------------------------------------------------
# Dead Letter Queue (optional)
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name = local.dlq_queue_name

  # FIFO settings (must match main queue)
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  # Encryption
  sqs_managed_sse_enabled = var.kms_key_arn == null
  kms_master_key_id       = var.kms_key_arn
  kms_data_key_reuse_period_seconds = var.kms_key_arn != null ? var.kms_data_key_reuse_period : null

  # Retention (keep DLQ messages longer for debugging)
  message_retention_seconds = var.dlq_message_retention_seconds

  tags = merge(var.tags, {
    Name = local.dlq_queue_name
    Type = "dead-letter-queue"
  })
}

# -----------------------------------------------------------------------------
# Main Queue
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "main" {
  name = local.queue_name

  # FIFO settings
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null
  deduplication_scope         = var.fifo_queue ? var.deduplication_scope : null
  fifo_throughput_limit       = var.fifo_queue ? var.fifo_throughput_limit : null

  # Message settings
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds

  # Encryption (always enabled)
  sqs_managed_sse_enabled = var.kms_key_arn == null
  kms_master_key_id       = var.kms_key_arn
  kms_data_key_reuse_period_seconds = var.kms_key_arn != null ? var.kms_data_key_reuse_period : null

  # Dead-letter queue
  dynamic "redrive_policy" {
    for_each = var.create_dlq ? [1] : []
    content {
      deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
      maxReceiveCount     = var.max_receive_count
    }
  }

  # External DLQ
  dynamic "redrive_policy" {
    for_each = var.dlq_arn != null ? [1] : []
    content {
      deadLetterTargetArn = var.dlq_arn
      maxReceiveCount     = var.max_receive_count
    }
  }

  tags = merge(var.tags, {
    Name = local.queue_name
  })
}

# -----------------------------------------------------------------------------
# Redrive Allow Policy (for DLQ)
# -----------------------------------------------------------------------------

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  count = var.create_dlq ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}

# -----------------------------------------------------------------------------
# Queue Policy
# -----------------------------------------------------------------------------

resource "aws_sqs_queue_policy" "main" {
  count = var.create_queue_policy ? 1 : 0

  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name}-policy"
    Statement = concat(
      # Deny non-HTTPS access
      [{
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "sqs:*"
        Resource  = aws_sqs_queue.main.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }],
      # Allow specified principals to send
      length(var.send_message_principals) > 0 ? [{
        Sid       = "AllowSendMessage"
        Effect    = "Allow"
        Principal = { AWS = var.send_message_principals }
        Action    = ["sqs:SendMessage"]
        Resource  = aws_sqs_queue.main.arn
      }] : [],
      # Allow specified principals to receive
      length(var.receive_message_principals) > 0 ? [{
        Sid       = "AllowReceiveMessage"
        Effect    = "Allow"
        Principal = { AWS = var.receive_message_principals }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.main.arn
      }] : [],
      # Allow SNS to send messages
      length(var.sns_topic_arns) > 0 ? [{
        Sid       = "AllowSNSPublish"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.main.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = var.sns_topic_arns
          }
        }
      }] : [],
      # Allow S3 to send notifications
      length(var.s3_bucket_arns) > 0 ? [{
        Sid       = "AllowS3Notification"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.main.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = var.s3_bucket_arns
          }
        }
      }] : [],
      # Allow EventBridge to send messages
      var.allow_eventbridge ? [{
        Sid       = "AllowEventBridge"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.main.arn
      }] : [],
      # Additional custom statements
      var.additional_policy_statements
    )
  })
}

# DLQ Policy (HTTPS only)
resource "aws_sqs_queue_policy" "dlq" {
  count = var.create_dlq ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "sqs:*"
      Resource  = aws_sqs_queue.dlq[0].arn
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.create_dlq && var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-dlq-messages"
  alarm_description   = "Messages in DLQ for ${var.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = var.dlq_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq[0].name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "age_of_oldest_message" {
  count = var.create_cloudwatch_alarms && var.oldest_message_alarm_threshold != null ? 1 : 0

  alarm_name          = "${var.name}-oldest-message-age"
  alarm_description   = "Age of oldest message in ${var.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.oldest_message_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  count = var.create_cloudwatch_alarms && var.queue_depth_alarm_threshold != null ? 1 : 0

  alarm_name          = "${var.name}-queue-depth"
  alarm_description   = "Queue depth for ${var.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = var.queue_depth_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = var.tags
}
