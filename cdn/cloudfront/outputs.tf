output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "distribution_status" {
  description = "CloudFront distribution status"
  value       = aws_cloudfront_distribution.main.status
}

output "distribution_etag" {
  description = "CloudFront distribution ETag"
  value       = aws_cloudfront_distribution.main.etag
}

output "origin_access_control_id" {
  description = "Origin Access Control ID (S3 origins)"
  value       = var.s3_origin != null ? aws_cloudfront_origin_access_control.s3[0].id : null
}

output "aliases" {
  description = "Distribution aliases (CNAMEs)"
  value       = aws_cloudfront_distribution.main.aliases
}

# Origin IDs for reference
output "s3_origin_id" {
  description = "S3 origin ID"
  value       = local.s3_origin_id
}

output "alb_origin_id" {
  description = "ALB origin ID"
  value       = local.alb_origin_id
}

output "custom_origin_ids" {
  description = "Custom origin IDs"
  value       = local.custom_origin_ids
}

# URL outputs
output "distribution_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "custom_urls" {
  description = "Custom domain URLs (if aliases configured)"
  value       = [for alias in var.aliases : "https://${alias}"]
}
