# -----------------------------------------------------------------------------
# Topic
# -----------------------------------------------------------------------------

output "topic_arn" {
  description = "Topic ARN"
  value       = aws_sns_topic.main.arn
}

output "topic_id" {
  description = "Topic ID"
  value       = aws_sns_topic.main.id
}

output "topic_name" {
  description = "Topic name"
  value       = aws_sns_topic.main.name
}

output "topic_owner" {
  description = "AWS account ID of topic owner"
  value       = aws_sns_topic.main.owner
}

# -----------------------------------------------------------------------------
# Subscriptions
# -----------------------------------------------------------------------------

output "sqs_subscription_arns" {
  description = "Map of SQS subscription ARNs"
  value       = { for k, v in aws_sns_topic_subscription.sqs : k => v.arn }
}

output "lambda_subscription_arns" {
  description = "Map of Lambda subscription ARNs"
  value       = { for k, v in aws_sns_topic_subscription.lambda : k => v.arn }
}

output "email_subscription_arns" {
  description = "Map of email subscription ARNs"
  value       = { for k, v in aws_sns_topic_subscription.email : k => v.arn }
}

output "https_subscription_arns" {
  description = "Map of HTTPS subscription ARNs"
  value       = { for k, v in aws_sns_topic_subscription.https : k => v.arn }
}

output "sms_subscription_arns" {
  description = "Map of SMS subscription ARNs"
  value       = { for k, v in aws_sns_topic_subscription.sms : k => v.arn }
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

output "fifo_topic" {
  description = "Is this a FIFO topic"
  value       = var.fifo_topic
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_sns_topic.main.kms_master_key_id
}

# -----------------------------------------------------------------------------
# IAM Policy Helpers
# -----------------------------------------------------------------------------

output "publish_policy" {
  description = "IAM policy document for publishing"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.main.arn
    }]
  })
}

output "subscribe_policy" {
  description = "IAM policy document for subscribing"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sns:Subscribe",
        "sns:ConfirmSubscription",
        "sns:Unsubscribe"
      ]
      Resource = aws_sns_topic.main.arn
    }]
  })
}

output "full_access_policy" {
  description = "IAM policy document for full topic access"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sns:Publish",
        "sns:Subscribe",
        "sns:ConfirmSubscription",
        "sns:Unsubscribe",
        "sns:GetTopicAttributes",
        "sns:ListSubscriptionsByTopic"
      ]
      Resource = aws_sns_topic.main.arn
    }]
  })
}
