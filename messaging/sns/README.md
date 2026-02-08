# SNS Topic Module

Creates secure SNS topics following AWS best practices.

## Security Features (Enforced)

- ✅ **Encryption at rest** — KMS encryption enabled by default
- ✅ **HTTPS only** — Denies non-TLS publish requests
- ✅ **Signature v2** — Modern signature version by default
- ✅ **Least privilege** — Fine-grained access policy

## Usage

### Basic Topic

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

module "alerts_topic" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name = "${module.naming.prefix}-alerts"

  # Allow CloudWatch to publish alarms
  allow_cloudwatch_alarms = true

  tags = module.tags.common_tags
}
```

### With SQS Subscription

```hcl
module "orders_topic" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name = "${module.naming.prefix}-orders"

  sqs_subscriptions = {
    processor = {
      queue_arn            = module.orders_queue.queue_arn
      raw_message_delivery = true
    }
    analytics = {
      queue_arn = module.analytics_queue.queue_arn
      filter_policy = {
        order_type = ["premium", "enterprise"]
      }
    }
  }

  tags = module.tags.common_tags
}
```

### With Lambda Subscription

```hcl
module "events_topic" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name = "${module.naming.prefix}-events"

  lambda_subscriptions = {
    processor = {
      function_arn = module.processor_lambda.function_arn
    }
    notifier = {
      function_arn = module.notifier_lambda.function_arn
      filter_policy = {
        event_type = ["user.created", "user.deleted"]
      }
      filter_policy_scope = "MessageBody"
    }
  }

  tags = module.tags.common_tags
}

# Grant SNS permission to invoke Lambda
resource "aws_lambda_permission" "sns" {
  for_each = module.events_topic.lambda_subscription_arns

  statement_id  = "AllowSNS-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.key == "processor" ? module.processor_lambda.function_name : module.notifier_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.events_topic.topic_arn
}
```

### Alert Topic with Email

```hcl
module "alerts_topic" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name         = "${module.naming.prefix}-alerts"
  display_name = "MyApp Alerts"

  allow_cloudwatch_alarms = true
  allow_budgets           = true

  email_subscriptions = {
    ops_team = "ops@example.com"
    oncall   = "oncall@example.com"
  }

  tags = module.tags.common_tags
}
```

### FIFO Topic

```hcl
module "audit_topic" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name       = "${module.naming.prefix}-audit"
  fifo_topic = true

  content_based_deduplication = true
  message_retention_period    = 86400  # 1 day

  sqs_subscriptions = {
    audit_log = {
      queue_arn = module.audit_queue.queue_arn  # Must also be FIFO
    }
  }

  tags = module.tags.common_tags
}
```

### Fan-out Pattern

```hcl
module "order_events" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name = "${module.naming.prefix}-order-events"

  sqs_subscriptions = {
    # Each service gets its own queue
    fulfillment = {
      queue_arn            = module.fulfillment_queue.queue_arn
      raw_message_delivery = true
    }
    billing = {
      queue_arn            = module.billing_queue.queue_arn
      raw_message_delivery = true
    }
    analytics = {
      queue_arn = module.analytics_queue.queue_arn
    }
    notifications = {
      queue_arn = module.notifications_queue.queue_arn
      filter_policy = {
        order_total = [{ numeric = [">=", 1000] }]
      }
    }
  }

  tags = module.tags.common_tags
}
```

### Cross-Account Publishing

```hcl
module "shared_events" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name = "${module.naming.prefix}-shared-events"

  # Allow specific accounts
  cross_account_ids = ["111111111111", "222222222222"]

  # Or allow entire organization
  # organization_id = "o-xxxxxxxxxx"

  tags = module.tags.common_tags
}
```

### S3 Event Notifications

```hcl
module "upload_notifications" {
  source = "github.com/Narcoleptic-Fox/tf-aws//messaging/sns"

  name = "${module.naming.prefix}-uploads"

  s3_bucket_arns = [module.uploads_bucket.bucket_arn]

  lambda_subscriptions = {
    processor = {
      function_arn = module.upload_processor.function_arn
    }
  }

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
| name | Topic name | `string` | n/a | yes |
| fifo_topic | Create FIFO topic | `bool` | `false` | no |
| kms_key_arn | KMS key ARN | `string` | `null` | no |
| enforce_https | Deny non-HTTPS requests | `bool` | `true` | no |
| allow_cloudwatch_alarms | Allow CloudWatch | `bool` | `false` | no |
| allow_eventbridge | Allow EventBridge | `bool` | `false` | no |
| sqs_subscriptions | SQS subscriptions | `map(object)` | `{}` | no |
| lambda_subscriptions | Lambda subscriptions | `map(object)` | `{}` | no |
| email_subscriptions | Email subscriptions | `map(string)` | `{}` | no |

See `variables.tf` for full list.

## Outputs

| Name | Description |
|------|-------------|
| topic_arn | Topic ARN |
| topic_name | Topic name |
| sqs_subscription_arns | SQS subscription ARNs |
| lambda_subscription_arns | Lambda subscription ARNs |
| publish_policy | IAM policy for publishers |

## Notes

- **FIFO**: Adds `.fifo` suffix automatically, requires FIFO SQS queues
- **Email subscriptions**: Require manual confirmation
- **Filter policies**: Support MessageAttributes (default) or MessageBody scope
- **Dead-letter queues**: Supported for failed deliveries
