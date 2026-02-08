# ECS Cluster Module

Creates an ECS cluster with Fargate capacity providers, service definitions,
task definitions with secrets, and auto scaling.

## Features

- Fargate and Fargate Spot capacity providers
- Container Insights monitoring
- Service with load balancer integration
- Task definition with Secrets Manager
- ECS Exec for debugging
- Auto scaling (CPU and memory-based)
- Deployment circuit breaker with rollback

## Usage

### Cluster Only

```hcl
module "ecs_cluster" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ecs-cluster"

  cluster_name              = "my-cluster"
  enable_container_insights = true
  enable_fargate_spot       = true

  create_service = false  # Just create the cluster

  tags = {
    Environment = "production"
  }
}
```

### Full Service with ALB

```hcl
module "ecs" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ecs-cluster"

  cluster_name = "api-cluster"

  # Service configuration
  create_service = true
  service_name   = "api-service"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids

  # Container
  container_name  = "api"
  container_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/api:latest"
  container_port  = 8080

  # Task resources
  task_cpu    = 512
  task_memory = 1024

  # Load balancer
  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.security_group_id

  # Environment
  environment_variables = {
    NODE_ENV = "production"
    LOG_LEVEL = "info"
  }

  # Secrets from Secrets Manager
  secrets = [
    {
      name       = "DB_PASSWORD"
      value_from = "arn:aws:secretsmanager:us-east-1:123456789:secret:prod/db-password"
    },
    {
      name       = "API_KEY"
      value_from = "arn:aws:secretsmanager:us-east-1:123456789:secret:prod/api-key"
    }
  ]

  # Health check
  health_check_command = "curl -f http://localhost:8080/health || exit 1"

  # Auto scaling
  enable_autoscaling = true
  min_capacity       = 2
  max_capacity       = 10
  cpu_target_value   = 70

  tags = {
    Environment = "production"
    Application = "api"
  }
}
```

### With Custom Task Policy

```hcl
module "ecs" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ecs-cluster"

  cluster_name   = "processor-cluster"
  create_service = true
  service_name   = "processor"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids

  container_name  = "processor"
  container_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/processor:latest"

  task_cpu    = 1024
  task_memory = 2048

  # Custom permissions for the task
  task_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${module.s3.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = module.sqs.queue_arn
      }
    ]
  })

  tags = {
    Environment = "production"
  }
}
```

### Cost Optimization with Fargate Spot

```hcl
module "ecs" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ecs-cluster"

  cluster_name        = "batch-cluster"
  enable_fargate_spot = true

  # Prefer Spot (weight 4) over On-Demand (weight 1)
  fargate_base_count  = 1    # At least 1 On-Demand
  fargate_weight      = 1
  fargate_spot_weight = 4

  # ... service config
}
```

## Using with tf-security

```hcl
module "iam_baseline" {
  source = "github.com/Narcoleptic-Fox/tf-security//aws/iam-baseline"

  name_prefix         = "my-app"
  create_ecs_task_role = true
  ecs_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789:secret:*"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the ECS cluster | `string` | n/a | yes |
| enable_container_insights | Enable Container Insights | `bool` | `true` | no |
| enable_fargate_spot | Enable Fargate Spot | `bool` | `true` | no |
| create_service | Create ECS service | `bool` | `true` | no |
| service_name | Name of the service | `string` | `null` | no |
| vpc_id | VPC ID | `string` | `null` | no |
| subnet_ids | Subnet IDs | `list(string)` | `[]` | no |
| container_name | Container name | `string` | `"app"` | no |
| container_image | Container image | `string` | `null` | no |
| container_port | Container port | `number` | `null` | no |
| task_cpu | Task CPU units | `number` | `256` | no |
| task_memory | Task memory (MB) | `number` | `512` | no |
| environment_variables | Environment variables | `map(string)` | `{}` | no |
| secrets | Secrets from Secrets Manager | `list(object)` | `[]` | no |
| target_group_arn | ALB target group ARN | `string` | `null` | no |
| enable_autoscaling | Enable auto scaling | `bool` | `true` | no |
| min_capacity | Minimum tasks | `number` | `1` | no |
| max_capacity | Maximum tasks | `number` | `4` | no |
| tags | Tags to apply | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ECS cluster ID |
| cluster_arn | ECS cluster ARN |
| service_id | ECS service ID |
| task_definition_arn | Task definition ARN |
| security_group_id | Service security group ID |
| execution_role_arn | Task execution role ARN |
| task_role_arn | Task role ARN |
| log_group_name | CloudWatch log group name |

## ECS Exec (Debugging)

Connect to running containers for debugging:

```bash
aws ecs execute-command \
  --cluster my-cluster \
  --task arn:aws:ecs:us-east-1:123456789:task/my-cluster/abc123 \
  --container app \
  --interactive \
  --command "/bin/sh"
```

## Security Considerations

- ✅ Tasks run in private subnets (no public IP)
- ✅ Secrets injected from Secrets Manager
- ✅ Least-privilege task execution role
- ✅ Separate task role for application permissions
- ✅ CloudWatch logs with optional KMS encryption
- ⚠️ Review container image for vulnerabilities
- ⚠️ Enable ECR image scanning
