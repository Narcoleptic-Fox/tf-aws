# SQS Queue Module

Creates secure SQS queues following AWS best practices.

## Security Features (Enforced)

- ✅ **Encryption at rest** — SQS-managed or KMS CMK
- ✅ **HTTPS only** — Denies non-TLS requests via queue policy
- ✅ **Dead-letter queue** — Created by default for failed messages
- ✅ **Long polling** — Enabled by default (20 seconds)
- ✅ **CloudWatch alarms** — DLQ monitoring enabled by default

## Usage

### Basic Queue

```hcl
module "naming" {
  source      = "github.com/Narcoleptic-Fox/tf-security//core/naming"
  project     = "myapp"
  environment = "prod"
  region      = "us-east-1"
}

module "tags" {
  source      = "github.com/Narcoleptic-Fox/tf-security//core/tagging"
  project     = "myapp"
  environment = "prod"
  owner       = "platform"
  cost_center = "engineering"
}

module "orders_queue" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sqs"

  name = "${module.naming.prefix}-orders"

  # DLQ alarm notifications
  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = module.tags.common_tags
}
```

### FIFO Queue

```hcl
module "events_queue" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sqs"

  name       = "${module.naming.prefix}-events"
  fifo_queue = true

  # Deduplication
  content_based_deduplication = true
  deduplication_scope         = "messageGroup"

  # High throughput FIFO
  fifo_throughput_limit = "perMessageGroupId"

  tags = module.tags.common_tags
}
```

### With SNS Subscription

```hcl
module "notifications_queue" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sqs"

  name = "${module.naming.prefix}-notifications"

  # Allow SNS to publish
  sns_topic_arns = [aws_sns_topic.notifications.arn]

  tags = module.tags.common_tags
}

# Subscribe queue to SNS topic
resource "aws_sns_topic_subscription" "queue" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "sqs"
  endpoint  = module.notifications_queue.queue_arn
}
```

### With S3 Event Notifications

```hcl
module "upload_queue" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sqs"

  name = "${module.naming.prefix}-uploads"

  # Allow S3 to send notifications
  s3_bucket_arns = [module.uploads_bucket.bucket_arn]

  tags = module.tags.common_tags
}
```

### With Lambda Consumer

```hcl
module "tasks_queue" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sqs"

  name = "${module.naming.prefix}-tasks"

  # Visibility timeout should be >= Lambda timeout
  visibility_timeout_seconds = 60

  # Allow Lambda to receive
  receive_message_principals = [module.processor_lambda.role_arn]

  tags = module.tags.common_tags
}

# Lambda event source mapping
resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = module.tasks_queue.queue_arn
  function_name    = module.processor_lambda.function_arn
  batch_size       = 10
}
```

### With KMS Encryption

```hcl
module "sensitive_queue" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sqs"

  name = "${module.naming.prefix}-sensitive"

  # Use customer-managed key
  kms_key_arn = module.encryption.kms_key_arn

  tags = module.tags.common_tags
}
```

### Producer/Consumer Pattern

```hcl
module "work_queue" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sqs"

  name = "${module.naming.prefix}-work"

  # Producers
  send_message_principals = [
    module.api_lambda.role_arn,
    module.scheduler_lambda.role_arn
  ]

  # Consumers
  receive_message_principals = [
    module.worker_lambda.role_arn
  ]

  # Monitoring
  queue_depth_alarm_threshold    = 1000
  oldest_message_alarm_threshold = 3600  # 1 hour

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = module.tags.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Queue name | `string` | n/a | yes |
| fifo_queue | Create FIFO queue | `bool` | `false` | no |
| create_dlq | Create dead-letter queue | `bool` | `true` | no |
| max_receive_count | Receives before DLQ | `number` | `3` | no |
| visibility_timeout_seconds | Visibility timeout | `number` | `30` | no |
| message_retention_seconds | Message retention | `number` | `345600` | no |
| kms_key_arn | KMS key for encryption | `string` | `null` | no |
| sns_topic_arns | SNS topics allowed to publish | `list(string)` | `[]` | no |
| s3_bucket_arns | S3 buckets allowed to notify | `list(string)` | `[]` | no |

See `variables.tf` for full list.

## Outputs

| Name | Description |
|------|-------------|
| queue_arn | Queue ARN |
| queue_url | Queue URL |
| queue_name | Queue name |
| dlq_arn | Dead-letter queue ARN |
| dlq_url | Dead-letter queue URL |
| send_message_policy | IAM policy JSON for producers |
| receive_message_policy | IAM policy JSON for consumers |

## Notes

- **Visibility timeout**: Should be >= your consumer's processing time
- **Long polling**: Enabled by default (20s) to reduce empty receives
- **FIFO**: Adds `.fifo` suffix automatically, max 300 TPS (3000 with batching)
- **DLQ retention**: Set to 14 days (max) by default for debugging
