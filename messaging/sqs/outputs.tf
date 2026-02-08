# -----------------------------------------------------------------------------
# Main Queue
# -----------------------------------------------------------------------------

output "queue_id" {
  description = "Queue URL"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "Queue ARN"
  value       = aws_sqs_queue.main.arn
}

output "queue_url" {
  description = "Queue URL"
  value       = aws_sqs_queue.main.url
}

output "queue_name" {
  description = "Queue name"
  value       = aws_sqs_queue.main.name
}

# -----------------------------------------------------------------------------
# Dead Letter Queue
# -----------------------------------------------------------------------------

output "dlq_id" {
  description = "DLQ URL"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_arn" {
  description = "DLQ ARN"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "DLQ URL"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "dlq_name" {
  description = "DLQ name"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].name : null
}

# -----------------------------------------------------------------------------
# Encryption
# -----------------------------------------------------------------------------

output "kms_key_id" {
  description = "KMS key ID (if using CMK)"
  value       = var.kms_key_arn
}

output "encryption_type" {
  description = "Encryption type (SQS or KMS)"
  value       = var.kms_key_arn != null ? "KMS" : "SQS"
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

output "fifo_queue" {
  description = "Is this a FIFO queue"
  value       = var.fifo_queue
}

output "visibility_timeout" {
  description = "Visibility timeout in seconds"
  value       = aws_sqs_queue.main.visibility_timeout_seconds
}

output "message_retention" {
  description = "Message retention in seconds"
  value       = aws_sqs_queue.main.message_retention_seconds
}

# -----------------------------------------------------------------------------
# IAM Policy Helpers
# -----------------------------------------------------------------------------

output "send_message_policy" {
  description = "IAM policy document for sending messages"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.main.arn
    }]
  })
}

output "receive_message_policy" {
  description = "IAM policy document for receiving messages"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ]
      Resource = aws_sqs_queue.main.arn
    }]
  })
}

output "full_access_policy" {
  description = "IAM policy document for full queue access"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ChangeMessageVisibility",
        "sqs:PurgeQueue"
      ]
      Resource = [
        aws_sqs_queue.main.arn,
        var.create_dlq ? aws_sqs_queue.dlq[0].arn : ""
      ]
    }]
  })
}
