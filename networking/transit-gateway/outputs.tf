output "transit_gateway_id" {
  description = "The ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  description = "The ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.arn
}

output "transit_gateway_owner_id" {
  description = "The AWS account ID of the Transit Gateway owner"
  value       = aws_ec2_transit_gateway.main.owner_id
}

output "transit_gateway_association_default_route_table_id" {
  description = "The ID of the default association route table"
  value       = aws_ec2_transit_gateway.main.association_default_route_table_id
}

output "transit_gateway_propagation_default_route_table_id" {
  description = "The ID of the default propagation route table"
  value       = aws_ec2_transit_gateway.main.propagation_default_route_table_id
}

output "route_table_ids" {
  description = "Map of route table names to IDs"
  value = {
    for k, v in aws_ec2_transit_gateway_route_table.main : k => v.id
  }
}

output "vpc_attachment_ids" {
  description = "Map of VPC attachment names to IDs"
  value = {
    for k, v in aws_ec2_transit_gateway_vpc_attachment.main : k => v.id
  }
}

output "ram_resource_share_arn" {
  description = "The ARN of the RAM resource share"
  value       = try(aws_ram_resource_share.tgw[0].arn, null)
}
