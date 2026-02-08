/**
 * # Transit Gateway Module
 *
 * Creates an AWS Transit Gateway for multi-VPC connectivity with
 * route tables and VPC attachments.
 *
 * Features:
 * - Transit Gateway with customizable ASN
 * - Multiple VPC attachments
 * - Separate route tables for traffic segmentation
 * - Cross-account sharing via RAM
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------------------------
# Transit Gateway
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway" "main" {
  description = var.description

  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments ? "enable" : "disable"
  default_route_table_association = var.default_route_table_association ? "enable" : "disable"
  default_route_table_propagation = var.default_route_table_propagation ? "enable" : "disable"
  dns_support                     = var.dns_support ? "enable" : "disable"
  vpn_ecmp_support                = var.vpn_ecmp_support ? "enable" : "disable"
  multicast_support               = var.multicast_support ? "enable" : "disable"

  tags = merge(var.tags, {
    Name = var.name
  })
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table" "main" {
  for_each = var.route_tables

  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
  })
}

# -----------------------------------------------------------------------------
# VPC Attachments
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  dns_support                                     = lookup(each.value, "dns_support", true) ? "enable" : "disable"
  ipv6_support                                    = lookup(each.value, "ipv6_support", false) ? "enable" : "disable"
  appliance_mode_support                          = lookup(each.value, "appliance_mode_support", false) ? "enable" : "disable"
  transit_gateway_default_route_table_association = var.default_route_table_association
  transit_gateway_default_route_table_propagation = var.default_route_table_propagation

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
  })
}

# -----------------------------------------------------------------------------
# Route Table Associations
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_association" "main" {
  for_each = {
    for k, v in var.vpc_attachments : k => v
    if lookup(v, "route_table", null) != null && !var.default_route_table_association
  }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main[each.value.route_table].id
}

# -----------------------------------------------------------------------------
# Route Table Propagations
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_propagation" "main" {
  for_each = {
    for item in flatten([
      for attach_key, attach_value in var.vpc_attachments : [
        for rt in lookup(attach_value, "propagate_to", []) : {
          key        = "${attach_key}-${rt}"
          attachment = attach_key
          route_table = rt
        }
      ]
    ]) : item.key => item
    if !var.default_route_table_propagation
  }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main[each.value.attachment].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main[each.value.route_table].id
}

# -----------------------------------------------------------------------------
# Static Routes
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route" "static" {
  for_each = var.static_routes

  destination_cidr_block         = each.value.destination_cidr
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main[each.value.route_table].id

  # Either attachment or blackhole
  transit_gateway_attachment_id = lookup(each.value, "attachment", null) != null ? aws_ec2_transit_gateway_vpc_attachment.main[each.value.attachment].id : null
  blackhole                     = lookup(each.value, "blackhole", false)
}

# -----------------------------------------------------------------------------
# Resource Access Manager Share (Cross-Account)
# -----------------------------------------------------------------------------

resource "aws_ram_resource_share" "tgw" {
  count = var.enable_ram_sharing ? 1 : 0

  name                      = "${var.name}-tgw-share"
  allow_external_principals = var.allow_external_principals

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-share"
  })
}

resource "aws_ram_resource_association" "tgw" {
  count = var.enable_ram_sharing ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_ram_principal_association" "tgw" {
  for_each = var.enable_ram_sharing ? toset(var.ram_principals) : toset([])

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}
