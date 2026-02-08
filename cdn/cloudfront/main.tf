/**
 * # CloudFront Distribution Module
 *
 * Creates a secure CloudFront distribution following AWS best practices.
 *
 * Security features:
 * - HTTPS only (redirect HTTP)
 * - Modern TLS policy (TLSv1.2+)
 * - Origin Access Control for S3
 * - WAF integration option
 * - Custom SSL certificate support
 * - Geo-restriction support
 * - Access logging
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  s3_origin_id  = var.s3_origin != null ? "S3-${var.s3_origin.bucket_name}" : null
  alb_origin_id = var.alb_origin != null ? "ALB-${var.alb_origin.domain_name}" : null
  custom_origin_ids = {
    for k, v in var.custom_origins : k => "Custom-${k}"
  }
}

# -----------------------------------------------------------------------------
# Origin Access Control (for S3)
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "s3" {
  count = var.s3_origin != null ? 1 : 0

  name                              = "${var.name}-oac"
  description                       = "OAC for ${var.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -----------------------------------------------------------------------------
# CloudFront Distribution
# -----------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "main" {
  enabled             = var.enabled
  is_ipv6_enabled     = var.is_ipv6_enabled
  comment             = var.comment
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.aliases
  web_acl_id          = var.web_acl_id
  http_version        = var.http_version

  # S3 Origin
  dynamic "origin" {
    for_each = var.s3_origin != null ? [var.s3_origin] : []
    content {
      domain_name              = origin.value.bucket_regional_domain_name
      origin_id                = local.s3_origin_id
      origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id
      origin_path              = lookup(origin.value, "origin_path", "")

      dynamic "origin_shield" {
        for_each = lookup(origin.value, "origin_shield_region", null) != null ? [1] : []
        content {
          enabled              = true
          origin_shield_region = origin.value.origin_shield_region
        }
      }
    }
  }

  # ALB/NLB Origin
  dynamic "origin" {
    for_each = var.alb_origin != null ? [var.alb_origin] : []
    content {
      domain_name = origin.value.domain_name
      origin_id   = local.alb_origin_id
      origin_path = lookup(origin.value, "origin_path", "")

      custom_origin_config {
        http_port                = lookup(origin.value, "http_port", 80)
        https_port               = lookup(origin.value, "https_port", 443)
        origin_protocol_policy   = lookup(origin.value, "protocol_policy", "https-only")
        origin_ssl_protocols     = lookup(origin.value, "ssl_protocols", ["TLSv1.2"])
        origin_read_timeout      = lookup(origin.value, "read_timeout", 30)
        origin_keepalive_timeout = lookup(origin.value, "keepalive_timeout", 5)
      }

      dynamic "custom_header" {
        for_each = lookup(origin.value, "custom_headers", {})
        content {
          name  = custom_header.key
          value = custom_header.value
        }
      }

      dynamic "origin_shield" {
        for_each = lookup(origin.value, "origin_shield_region", null) != null ? [1] : []
        content {
          enabled              = true
          origin_shield_region = origin.value.origin_shield_region
        }
      }
    }
  }

  # Custom Origins
  dynamic "origin" {
    for_each = var.custom_origins
    content {
      domain_name = origin.value.domain_name
      origin_id   = local.custom_origin_ids[origin.key]
      origin_path = lookup(origin.value, "origin_path", "")

      custom_origin_config {
        http_port                = lookup(origin.value, "http_port", 80)
        https_port               = lookup(origin.value, "https_port", 443)
        origin_protocol_policy   = lookup(origin.value, "protocol_policy", "https-only")
        origin_ssl_protocols     = lookup(origin.value, "ssl_protocols", ["TLSv1.2"])
        origin_read_timeout      = lookup(origin.value, "read_timeout", 30)
        origin_keepalive_timeout = lookup(origin.value, "keepalive_timeout", 5)
      }

      dynamic "custom_header" {
        for_each = lookup(origin.value, "custom_headers", {})
        content {
          name  = custom_header.key
          value = custom_header.value
        }
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods  = var.default_cache_behavior.allowed_methods
    cached_methods   = var.default_cache_behavior.cached_methods
    target_origin_id = coalesce(
      var.default_cache_behavior.target_origin_id,
      local.s3_origin_id,
      local.alb_origin_id,
      try(values(local.custom_origin_ids)[0], null)
    )

    # Always redirect HTTP to HTTPS
    viewer_protocol_policy = "redirect-to-https"

    compress = var.default_cache_behavior.compress

    # Cache policy
    cache_policy_id            = var.default_cache_behavior.cache_policy_id
    origin_request_policy_id   = var.default_cache_behavior.origin_request_policy_id
    response_headers_policy_id = var.default_cache_behavior.response_headers_policy_id

    # Legacy TTL settings (used if no cache policy)
    dynamic "forwarded_values" {
      for_each = var.default_cache_behavior.cache_policy_id == null ? [1] : []
      content {
        query_string = lookup(var.default_cache_behavior, "forward_query_string", false)
        headers      = lookup(var.default_cache_behavior, "forward_headers", [])

        cookies {
          forward = lookup(var.default_cache_behavior, "forward_cookies", "none")
        }
      }
    }

    min_ttl     = var.default_cache_behavior.cache_policy_id == null ? lookup(var.default_cache_behavior, "min_ttl", 0) : null
    default_ttl = var.default_cache_behavior.cache_policy_id == null ? lookup(var.default_cache_behavior, "default_ttl", 86400) : null
    max_ttl     = var.default_cache_behavior.cache_policy_id == null ? lookup(var.default_cache_behavior, "max_ttl", 31536000) : null

    # Function associations
    dynamic "function_association" {
      for_each = lookup(var.default_cache_behavior, "function_associations", [])
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }

    # Lambda@Edge associations
    dynamic "lambda_function_association" {
      for_each = lookup(var.default_cache_behavior, "lambda_function_associations", [])
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lookup(lambda_function_association.value, "include_body", false)
      }
    }
  }

  # Ordered Cache Behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = ordered_cache_behavior.value.allowed_methods
      cached_methods   = ordered_cache_behavior.value.cached_methods
      target_origin_id = ordered_cache_behavior.value.target_origin_id

      viewer_protocol_policy = "redirect-to-https"
      compress               = lookup(ordered_cache_behavior.value, "compress", true)

      cache_policy_id            = lookup(ordered_cache_behavior.value, "cache_policy_id", null)
      origin_request_policy_id   = lookup(ordered_cache_behavior.value, "origin_request_policy_id", null)
      response_headers_policy_id = lookup(ordered_cache_behavior.value, "response_headers_policy_id", null)

      dynamic "forwarded_values" {
        for_each = lookup(ordered_cache_behavior.value, "cache_policy_id", null) == null ? [1] : []
        content {
          query_string = lookup(ordered_cache_behavior.value, "forward_query_string", false)
          headers      = lookup(ordered_cache_behavior.value, "forward_headers", [])

          cookies {
            forward = lookup(ordered_cache_behavior.value, "forward_cookies", "none")
          }
        }
      }

      min_ttl     = lookup(ordered_cache_behavior.value, "cache_policy_id", null) == null ? lookup(ordered_cache_behavior.value, "min_ttl", 0) : null
      default_ttl = lookup(ordered_cache_behavior.value, "cache_policy_id", null) == null ? lookup(ordered_cache_behavior.value, "default_ttl", 86400) : null
      max_ttl     = lookup(ordered_cache_behavior.value, "cache_policy_id", null) == null ? lookup(ordered_cache_behavior.value, "max_ttl", 31536000) : null

      dynamic "function_association" {
        for_each = lookup(ordered_cache_behavior.value, "function_associations", [])
        content {
          event_type   = function_association.value.event_type
          function_arn = function_association.value.function_arn
        }
      }

      dynamic "lambda_function_association" {
        for_each = lookup(ordered_cache_behavior.value, "lambda_function_associations", [])
        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lookup(lambda_function_association.value, "include_body", false)
        }
      }
    }
  }

  # Custom Error Responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = lookup(custom_error_response.value, "response_code", null)
      response_page_path    = lookup(custom_error_response.value, "response_page_path", null)
      error_caching_min_ttl = lookup(custom_error_response.value, "error_caching_min_ttl", 300)
    }
  }

  # Geo Restriction
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction.restriction_type
      locations        = var.geo_restriction.locations
    }
  }

  # SSL/TLS Configuration
  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    cloudfront_default_certificate = var.acm_certificate_arn == null
    minimum_protocol_version       = var.acm_certificate_arn != null ? var.minimum_protocol_version : "TLSv1"
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
  }

  # Access Logging
  dynamic "logging_config" {
    for_each = var.logging_bucket != null ? [1] : []
    content {
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
      include_cookies = var.logging_include_cookies
    }
  }

  tags = merge(var.tags, {
    Name = var.name
  })

  lifecycle {
    precondition {
      condition     = var.s3_origin != null || var.alb_origin != null || length(var.custom_origins) > 0
      error_message = "At least one origin must be specified."
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket Policy for OAC
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "s3_oac" {
  count = var.s3_origin != null && var.create_s3_bucket_policy ? 1 : 0

  statement {
    sid       = "AllowCloudFrontServicePrincipal"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_origin.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "oac" {
  count = var.s3_origin != null && var.create_s3_bucket_policy ? 1 : 0

  bucket = var.s3_origin.bucket_name
  policy = data.aws_iam_policy_document.s3_oac[0].json
}

# -----------------------------------------------------------------------------
# Route53 Record (optional)
# -----------------------------------------------------------------------------

resource "aws_route53_record" "alias" {
  for_each = var.route53_records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
