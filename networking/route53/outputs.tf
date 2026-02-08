output "public_zone_id" {
  description = "The ID of the public hosted zone"
  value       = try(aws_route53_zone.public[0].zone_id, null)
}

output "public_zone_arn" {
  description = "The ARN of the public hosted zone"
  value       = try(aws_route53_zone.public[0].arn, null)
}

output "public_zone_name_servers" {
  description = "Name servers for the public hosted zone"
  value       = try(aws_route53_zone.public[0].name_servers, null)
}

output "private_zone_id" {
  description = "The ID of the private hosted zone"
  value       = try(aws_route53_zone.private[0].zone_id, null)
}

output "private_zone_arn" {
  description = "The ARN of the private hosted zone"
  value       = try(aws_route53_zone.private[0].arn, null)
}

output "record_names" {
  description = "Map of record keys to their FQDNs"
  value = {
    for k, v in aws_route53_record.main : k => v.fqdn
  }
}

output "health_check_ids" {
  description = "Map of health check names to their IDs"
  value = {
    for k, v in aws_route53_health_check.main : k => v.id
  }
}

output "zone_id" {
  description = "The zone ID (public or private based on what was created)"
  value       = coalesce(
    try(aws_route53_zone.public[0].zone_id, null),
    try(aws_route53_zone.private[0].zone_id, null),
    var.existing_zone_id
  )
}
