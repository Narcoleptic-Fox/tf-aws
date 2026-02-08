/**
 * # ECS Cluster Module
 *
 * Creates an ECS cluster with Fargate and EC2 capacity providers,
 * service definitions, and task definitions with secrets support.
 *
 * Features:
 * - Fargate and Fargate Spot capacity providers
 * - EC2 capacity provider (optional)
 * - Container Insights monitoring
 * - Service with load balancer integration
 * - Task definition with Secrets Manager integration
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/ecs/${var.cluster_name}/exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Capacity Providers
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = compact([
    "FARGATE",
    var.enable_fargate_spot ? "FARGATE_SPOT" : ""
  ])

  default_capacity_provider_strategy {
    base              = var.fargate_base_count
    weight            = var.fargate_weight
    capacity_provider = "FARGATE"
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = var.enable_fargate_spot ? [1] : []
    content {
      weight            = var.fargate_spot_weight
      capacity_provider = "FARGATE_SPOT"
    }
  }
}

# -----------------------------------------------------------------------------
# Service Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "service" {
  count = var.create_service ? 1 : 0

  name_prefix = "${var.service_name}-"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.service_name} ECS service"

  tags = merge(var.tags, {
    Name = "${var.service_name}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "service_ingress" {
  count = var.create_service && var.container_port != null ? 1 : 0

  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.service[0].id
  source_security_group_id = var.alb_security_group_id
  description              = "From load balancer"
}

resource "aws_security_group_rule" "service_egress" {
  count = var.create_service ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service[0].id
  description       = "All outbound traffic"
}

# -----------------------------------------------------------------------------
# IAM Roles
# -----------------------------------------------------------------------------

# Task Execution Role (for ECS agent)
resource "aws_iam_role" "execution" {
  count = var.create_service ? 1 : 0

  name        = "${var.service_name}-execution"
  description = "ECS task execution role for ${var.service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  count = var.create_service ? 1 : 0

  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = var.create_service && length(var.secrets) > 0 ? 1 : 0

  name = "secrets-access"
  role = aws_iam_role.execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          for s in var.secrets : s.value_from
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "execution_kms" {
  count = var.create_service && var.kms_key_arn != null ? 1 : 0

  name = "kms-decrypt"
  role = aws_iam_role.execution[0].id

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

# Task Role (for application)
resource "aws_iam_role" "task" {
  count = var.create_service ? 1 : 0

  name        = "${var.service_name}-task"
  description = "ECS task role for ${var.service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = local.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ecs:${local.region}:${local.account_id}:*"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "task_custom" {
  count = var.create_service && var.task_policy_json != null ? 1 : 0

  name   = "application-permissions"
  role   = aws_iam_role.task[0].id
  policy = var.task_policy_json
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group (for containers)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "service" {
  count = var.create_service ? 1 : 0

  name              = "/ecs/${var.cluster_name}/${var.service_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Task Definition
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "main" {
  count = var.create_service ? 1 : 0

  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution[0].arn
  task_role_arn            = aws_iam_role.task[0].arn

  container_definitions = jsonencode([
    {
      name  = var.container_name
      image = var.container_image

      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true

      portMappings = var.container_port != null ? [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ] : []

      environment = [
        for k, v in var.environment_variables : {
          name  = k
          value = v
        }
      ]

      secrets = [
        for s in var.secrets : {
          name      = s.name
          valueFrom = s.value_from
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service[0].name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = var.container_name
        }
      }

      healthCheck = var.health_check_command != null ? {
        command     = ["CMD-SHELL", var.health_check_command]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = var.health_check_start_period
      } : null
    }
  ])

  tags = var.tags
}

# -----------------------------------------------------------------------------
# ECS Service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "main" {
  count = var.create_service ? 1 : 0

  name            = var.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main[0].arn
  desired_count   = var.desired_count

  launch_type         = "FARGATE"
  platform_version    = "LATEST"
  scheduling_strategy = "REPLICA"

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.target_group_arn != null ? var.health_check_grace_period : null

  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.service[0].id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = var.enable_deployment_rollback
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling
# -----------------------------------------------------------------------------

resource "aws_appautoscaling_target" "service" {
  count = var.create_service && var.enable_autoscaling ? 1 : 0

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.create_service && var.enable_autoscaling ? 1 : 0

  name               = "${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count = var.create_service && var.enable_autoscaling && var.enable_memory_scaling ? 1 : 0

  name               = "${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}
