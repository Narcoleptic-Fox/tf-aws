/**
 * # Route 53 Module
 *
 * Manages Route 53 hosted zones, DNS records, and health checks.
 *
 * Features:
 * - Public and private hosted zones
 * - Record sets (A, AAAA, CNAME, ALIAS, MX, TXT, etc.)
 * - Health checks with optional CloudWatch alarms
 * - Failover routing support
 */

# -----------------------------------------------------------------------------
# Hosted Zones
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "public" {
  count = var.create_public_zone ? 1 : 0

  name          = var.domain_name
  comment       = var.zone_comment
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.domain_name
    Type = "public"
  })
}

resource "aws_route53_zone" "private" {
  count = var.create_private_zone ? 1 : 0

  name    = var.private_zone_name != null ? var.private_zone_name : var.domain_name
  comment = var.zone_comment

  dynamic "vpc" {
    for_each = var.private_zone_vpcs
    content {
      vpc_id     = vpc.value.vpc_id
      vpc_region = lookup(vpc.value, "vpc_region", null)
    }
  }

  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.private_zone_name != null ? var.private_zone_name : var.domain_name
    Type = "private"
  })
}

# -----------------------------------------------------------------------------
# DNS Records
# -----------------------------------------------------------------------------

resource "aws_route53_record" "main" {
  for_each = var.records

  zone_id = each.value.zone_type == "private" ? (
    var.create_private_zone ? aws_route53_zone.private[0].zone_id : var.existing_zone_id
  ) : (
    var.create_public_zone ? aws_route53_zone.public[0].zone_id : var.existing_zone_id
  )

  name = each.value.name
  type = each.value.type

  # Standard records
  ttl     = lookup(each.value, "alias", null) == null ? lookup(each.value, "ttl", 300) : null
  records = lookup(each.value, "alias", null) == null ? each.value.records : null

  # Alias records
  dynamic "alias" {
    for_each = lookup(each.value, "alias", null) != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = lookup(alias.value, "evaluate_target_health", true)
    }
  }

  # Routing policy
  set_identifier = lookup(each.value, "set_identifier", null)

  # Weighted routing
  dynamic "weighted_routing_policy" {
    for_each = lookup(each.value, "weighted", null) != null ? [each.value.weighted] : []
    content {
      weight = weighted_routing_policy.value.weight
    }
  }

  # Latency routing
  dynamic "latency_routing_policy" {
    for_each = lookup(each.value, "latency", null) != null ? [each.value.latency] : []
    content {
      region = latency_routing_policy.value.region
    }
  }

  # Failover routing
  dynamic "failover_routing_policy" {
    for_each = lookup(each.value, "failover", null) != null ? [each.value.failover] : []
    content {
      type = failover_routing_policy.value.type
    }
  }

  # Geolocation routing
  dynamic "geolocation_routing_policy" {
    for_each = lookup(each.value, "geolocation", null) != null ? [each.value.geolocation] : []
    content {
      continent   = lookup(geolocation_routing_policy.value, "continent", null)
      country     = lookup(geolocation_routing_policy.value, "country", null)
      subdivision = lookup(geolocation_routing_policy.value, "subdivision", null)
    }
  }

  # Health check
  health_check_id = lookup(each.value, "health_check", null) != null ? (
    aws_route53_health_check.main[each.value.health_check].id
  ) : null

  allow_overwrite = lookup(each.value, "allow_overwrite", false)
}

# -----------------------------------------------------------------------------
# Health Checks
# -----------------------------------------------------------------------------

resource "aws_route53_health_check" "main" {
  for_each = var.health_checks

  # HTTP/HTTPS health checks
  fqdn              = lookup(each.value, "fqdn", null)
  ip_address        = lookup(each.value, "ip_address", null)
  port              = lookup(each.value, "port", each.value.type == "HTTPS" ? 443 : 80)
  type              = each.value.type
  resource_path     = lookup(each.value, "resource_path", "/")
  request_interval  = lookup(each.value, "request_interval", 30)
  failure_threshold = lookup(each.value, "failure_threshold", 3)

  # For HTTPS
  enable_sni = lookup(each.value, "enable_sni", each.value.type == "HTTPS")

  # String matching
  search_string = lookup(each.value, "search_string", null)

  # Regions
  regions = lookup(each.value, "regions", null)

  # Invert health check
  invert_healthcheck = lookup(each.value, "invert", false)

  # Disabled
  disabled = lookup(each.value, "disabled", false)

  # Calculated health check
  child_healthchecks          = lookup(each.value, "child_healthchecks", null)
  child_health_threshold      = lookup(each.value, "child_health_threshold", null)
  insufficient_data_health_status = lookup(each.value, "insufficient_data_status", null)

  # CloudWatch alarm
  cloudwatch_alarm_name   = lookup(each.value, "cloudwatch_alarm_name", null)
  cloudwatch_alarm_region = lookup(each.value, "cloudwatch_alarm_region", null)

  tags = merge(var.tags, {
    Name = each.key
  })
}

# -----------------------------------------------------------------------------
# VPC Association (for private zones)
# -----------------------------------------------------------------------------

resource "aws_route53_zone_association" "additional" {
  for_each = var.additional_vpc_associations

  zone_id    = var.create_private_zone ? aws_route53_zone.private[0].zone_id : var.existing_zone_id
  vpc_id     = each.value.vpc_id
  vpc_region = lookup(each.value, "vpc_region", null)
}

# -----------------------------------------------------------------------------
# Query Logging (optional)
# -----------------------------------------------------------------------------

resource "aws_route53_query_log" "main" {
  count = var.enable_query_logging ? 1 : 0

  cloudwatch_log_group_arn = var.query_log_group_arn
  zone_id                  = var.create_public_zone ? aws_route53_zone.public[0].zone_id : var.existing_zone_id
}
