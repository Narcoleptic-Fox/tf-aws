output "bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for the bucket"
  value       = aws_s3_bucket.main.hosted_zone_id
}

output "bucket_region" {
  description = "The AWS region of the bucket"
  value       = aws_s3_bucket.main.region
}

output "website_endpoint" {
  description = "The website endpoint (if website configured)"
  value       = try(aws_s3_bucket_website_configuration.main[0].website_endpoint, null)
}

output "website_domain" {
  description = "The website domain (if website configured)"
  value       = try(aws_s3_bucket_website_configuration.main[0].website_domain, null)
}
