output "function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "invoke_arn" {
  description = "The ARN to invoke the Lambda function"
  value       = aws_lambda_function.main.invoke_arn
}

output "qualified_arn" {
  description = "The qualified ARN (includes version)"
  value       = aws_lambda_function.main.qualified_arn
}

output "version" {
  description = "The version of the Lambda function"
  value       = aws_lambda_function.main.version
}

output "role_arn" {
  description = "The ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "The name of the Lambda execution role"
  value       = aws_iam_role.lambda.name
}

output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

output "function_url" {
  description = "The Lambda function URL"
  value       = try(aws_lambda_function_url.main[0].function_url, null)
}

output "alias_arn" {
  description = "The ARN of the Lambda alias"
  value       = try(aws_lambda_alias.main[0].arn, null)
}

output "alias_invoke_arn" {
  description = "The invoke ARN of the Lambda alias"
  value       = try(aws_lambda_alias.main[0].invoke_arn, null)
}
