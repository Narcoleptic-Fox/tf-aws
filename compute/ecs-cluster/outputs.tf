output "cluster_id" {
  description = "The ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_id" {
  description = "The ID of the ECS service"
  value       = try(aws_ecs_service.main[0].id, null)
}

output "service_name" {
  description = "The name of the ECS service"
  value       = try(aws_ecs_service.main[0].name, null)
}

output "task_definition_arn" {
  description = "The ARN of the task definition"
  value       = try(aws_ecs_task_definition.main[0].arn, null)
}

output "task_definition_family" {
  description = "The family of the task definition"
  value       = try(aws_ecs_task_definition.main[0].family, null)
}

output "task_definition_revision" {
  description = "The revision of the task definition"
  value       = try(aws_ecs_task_definition.main[0].revision, null)
}

output "security_group_id" {
  description = "The ID of the service security group"
  value       = try(aws_security_group.service[0].id, null)
}

output "execution_role_arn" {
  description = "The ARN of the task execution role"
  value       = try(aws_iam_role.execution[0].arn, null)
}

output "task_role_arn" {
  description = "The ARN of the task role"
  value       = try(aws_iam_role.task[0].arn, null)
}

output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = try(aws_cloudwatch_log_group.service[0].name, null)
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group"
  value       = try(aws_cloudwatch_log_group.service[0].arn, null)
}
