# Lambda Module

Creates a Lambda function with CloudWatch Logs, optional VPC attachment,
environment variables, secrets, and event source mappings.

## Features

- Multiple deployment options (zip, S3, container image)
- VPC attachment for private resources
- Environment variables and Secrets Manager integration
- X-Ray tracing
- Dead letter queue (SQS/SNS)
- Function URL
- Event source mappings (SQS, DynamoDB, Kinesis)
- Lambda permissions for API Gateway, S3, etc.

## Usage

### Basic Function (Zip Package)

```hcl
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

module "lambda" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/lambda"

  function_name    = "my-function"
  description      = "Processes incoming events"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs20.x"

  memory_size = 256
  timeout     = 30

  environment_variables = {
    NODE_ENV  = "production"
    LOG_LEVEL = "info"
  }

  tags = {
    Environment = "production"
  }
}
```

### Container-Based Lambda

```hcl
module "lambda" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/lambda"

  function_name = "container-function"
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/my-lambda:latest"

  memory_size = 512
  timeout     = 60

  tags = {
    Environment = "production"
  }
}
```

### VPC-Attached Lambda

```hcl
module "lambda" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/lambda"

  function_name    = "vpc-function"
  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")
  handler          = "index.handler"
  runtime          = "python3.12"

  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Access secrets
  secret_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789:secret:db-password-*"
  ]

  # Custom permissions (e.g., RDS access)
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["rds-db:connect"]
      Resource = "arn:aws:rds-db:us-east-1:123456789:dbuser:*/lambda"
    }]
  })

  tags = {
    Environment = "production"
  }
}
```

### SQS Event Source

```hcl
module "lambda" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/lambda"

  function_name    = "sqs-processor"
  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")
  handler          = "index.handler"
  runtime          = "nodejs20.x"

  event_source_mappings = {
    "main-queue" = {
      event_source_arn = module.sqs.queue_arn
      batch_size       = 10
    }
  }

  # Grant SQS permissions
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = module.sqs.queue_arn
    }]
  })

  tags = {
    Environment = "production"
  }
}
```

### With API Gateway Permission

```hcl
module "lambda" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/lambda"

  function_name    = "api-handler"
  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")
  handler          = "index.handler"
  runtime          = "nodejs20.x"

  permissions = {
    "api_gateway" = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*"
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### With Function URL

```hcl
module "lambda" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/lambda"

  function_name    = "webhook-handler"
  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")
  handler          = "index.handler"
  runtime          = "nodejs20.x"

  create_function_url    = true
  function_url_auth_type = "NONE"  # Public webhook

  function_url_cors = {
    allow_origins = ["https://example.com"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
  }

  tags = {
    Environment = "production"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| function_name | Function name | `string` | n/a | yes |
| description | Description | `string` | `null` | no |
| filename | Path to zip file | `string` | `null` | no |
| source_code_hash | Hash of the package | `string` | `null` | no |
| image_uri | ECR image URI | `string` | `null` | no |
| handler | Function handler | `string` | `"index.handler"` | no |
| runtime | Lambda runtime | `string` | `"nodejs20.x"` | no |
| architecture | CPU architecture | `string` | `"arm64"` | no |
| memory_size | Memory in MB | `number` | `128` | no |
| timeout | Timeout in seconds | `number` | `30` | no |
| environment_variables | Env vars | `map(string)` | `{}` | no |
| vpc_config | VPC configuration | `object` | `null` | no |
| secret_arns | Secrets to access | `list(string)` | `[]` | no |
| tracing_mode | X-Ray mode | `string` | `"PassThrough"` | no |
| dead_letter_target_arn | DLQ ARN | `string` | `null` | no |
| policy_json | Custom IAM policy | `string` | `null` | no |
| create_function_url | Create URL | `bool` | `false` | no |
| event_source_mappings | Event sources | `map(object)` | `{}` | no |
| permissions | Invocation perms | `map(object)` | `{}` | no |
| tags | Tags to apply | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| function_name | Function name |
| function_arn | Function ARN |
| invoke_arn | Invoke ARN |
| qualified_arn | Qualified ARN with version |
| version | Current version |
| role_arn | Execution role ARN |
| log_group_name | Log group name |
| function_url | Function URL (if created) |

## Best Practices

### ARM64 Architecture

The module defaults to ARM64 (Graviton2) for:
- Better price/performance
- Lower carbon footprint
- Same code compatibility for most runtimes

Override with `architecture = "x86_64"` if needed.

### VPC Lambda

When using VPC attachment:
- Place in private subnets with NAT
- Use VPC endpoints for AWS services
- Consider Provisioned Concurrency for cold starts

## Security Considerations

- ✅ Least-privilege execution role
- ✅ Secrets via Secrets Manager (not env vars)
- ✅ CloudWatch logs with optional KMS
- ✅ VPC isolation available
- ⚠️ Function URL with NONE auth is public
- ⚠️ Review event source permissions carefully
