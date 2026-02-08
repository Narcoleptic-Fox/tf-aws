output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = try(aws_instance.main[0].id, null)
}

output "instance_arn" {
  description = "The ARN of the EC2 instance"
  value       = try(aws_instance.main[0].arn, null)
}

output "instance_private_ip" {
  description = "The private IP address of the instance"
  value       = try(aws_instance.main[0].private_ip, null)
}

output "instance_public_ip" {
  description = "The public IP address of the instance (if assigned)"
  value       = try(aws_instance.main[0].public_ip, null)
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = aws_launch_template.main.id
}

output "launch_template_arn" {
  description = "The ARN of the launch template"
  value       = aws_launch_template.main.arn
}

output "launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = aws_launch_template.main.latest_version
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.instance.id
}

output "iam_role_arn" {
  description = "The ARN of the IAM role"
  value       = aws_iam_role.instance.arn
}

output "iam_role_name" {
  description = "The name of the IAM role"
  value       = aws_iam_role.instance.name
}

output "instance_profile_arn" {
  description = "The ARN of the instance profile"
  value       = aws_iam_instance_profile.instance.arn
}

output "instance_profile_name" {
  description = "The name of the instance profile"
  value       = aws_iam_instance_profile.instance.name
}
