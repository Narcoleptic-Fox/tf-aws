variable "name" {
  description = "Name for the CloudFront distribution"
  type        = string
}

variable "enabled" {
  description = "Enable the distribution"
  type        = bool
  default     = true
}

variable "is_ipv6_enabled" {
  description = "Enable IPv6"
  type        = bool
  default     = true
}

variable "comment" {
  description = "Distribution comment"
  type        = string
  default     = null
}

variable "default_root_object" {
  description = "Default root object (e.g., index.html)"
  type        = string
  default     = null
}

variable "price_class" {
  description = "Price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "aliases" {
  description = "Alternate domain names (CNAMEs)"
  type        = list(string)
  default     = []
}

variable "web_acl_id" {
  description = "WAF web ACL ARN"
  type        = string
  default     = null
}

variable "http_version" {
  description = "HTTP version (http1.1, http2, http2and3, http3)"
  type        = string
  default     = "http2and3"
}

# -----------------------------------------------------------------------------
# Origins
# -----------------------------------------------------------------------------

variable "s3_origin" {
  description = "S3 bucket origin configuration"
  type = object({
    bucket_name                = string
    bucket_arn                 = string
    bucket_regional_domain_name = string
    origin_path                = optional(string, "")
    origin_shield_region       = optional(string)
  })
  default = null
}

variable "alb_origin" {
  description = "ALB/NLB origin configuration"
  type = object({
    domain_name          = string
    origin_path          = optional(string, "")
    http_port            = optional(number, 80)
    https_port           = optional(number, 443)
    protocol_policy      = optional(string, "https-only")
    ssl_protocols        = optional(list(string), ["TLSv1.2"])
    read_timeout         = optional(number, 30)
    keepalive_timeout    = optional(number, 5)
    custom_headers       = optional(map(string), {})
    origin_shield_region = optional(string)
  })
  default = null
}

variable "custom_origins" {
  description = "Custom origin configurations"
  type = map(object({
    domain_name          = string
    origin_path          = optional(string, "")
    http_port            = optional(number, 80)
    https_port           = optional(number, 443)
    protocol_policy      = optional(string, "https-only")
    ssl_protocols        = optional(list(string), ["TLSv1.2"])
    read_timeout         = optional(number, 30)
    keepalive_timeout    = optional(number, 5)
    custom_headers       = optional(map(string), {})
  }))
  default = {}
}

variable "create_s3_bucket_policy" {
  description = "Create S3 bucket policy for OAC"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Cache Behaviors
# -----------------------------------------------------------------------------

variable "default_cache_behavior" {
  description = "Default cache behavior configuration"
  type = object({
    allowed_methods            = optional(list(string), ["GET", "HEAD"])
    cached_methods             = optional(list(string), ["GET", "HEAD"])
    target_origin_id           = optional(string)
    compress                   = optional(bool, true)
    cache_policy_id            = optional(string)
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)
    # Legacy forwarding (used if no cache policy)
    forward_query_string       = optional(bool, false)
    forward_headers            = optional(list(string), [])
    forward_cookies            = optional(string, "none")
    min_ttl                    = optional(number, 0)
    default_ttl                = optional(number, 86400)
    max_ttl                    = optional(number, 31536000)
    # Functions
    function_associations = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])
    lambda_function_associations = optional(list(object({
      event_type   = string
      lambda_arn   = string
      include_body = optional(bool, false)
    })), [])
  })
  default = {}
}

variable "ordered_cache_behaviors" {
  description = "Ordered cache behaviors"
  type = list(object({
    path_pattern               = string
    allowed_methods            = list(string)
    cached_methods             = list(string)
    target_origin_id           = string
    compress                   = optional(bool, true)
    cache_policy_id            = optional(string)
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)
    forward_query_string       = optional(bool, false)
    forward_headers            = optional(list(string), [])
    forward_cookies            = optional(string, "none")
    min_ttl                    = optional(number, 0)
    default_ttl                = optional(number, 86400)
    max_ttl                    = optional(number, 31536000)
    function_associations = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])
    lambda_function_associations = optional(list(object({
      event_type   = string
      lambda_arn   = string
      include_body = optional(bool, false)
    })), [])
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Custom Error Responses
# -----------------------------------------------------------------------------

variable "custom_error_responses" {
  description = "Custom error response configurations"
  type = list(object({
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
    error_caching_min_ttl = optional(number, 300)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Geo Restriction
# -----------------------------------------------------------------------------

variable "geo_restriction" {
  description = "Geo restriction configuration"
  type = object({
    restriction_type = string
    locations        = list(string)
  })
  default = {
    restriction_type = "none"
    locations        = []
  }
}

# -----------------------------------------------------------------------------
# SSL/TLS
# -----------------------------------------------------------------------------

variable "acm_certificate_arn" {
  description = "ACM certificate ARN (us-east-1 only)"
  type        = string
  default     = null
}

variable "minimum_protocol_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "TLSv1.2_2021"
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "logging_bucket" {
  description = "S3 bucket for access logs (bucket.s3.amazonaws.com format)"
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for log files"
  type        = string
  default     = "cloudfront/"
}

variable "logging_include_cookies" {
  description = "Include cookies in access logs"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Route53
# -----------------------------------------------------------------------------

variable "route53_records" {
  description = "Route53 alias records to create"
  type = map(object({
    zone_id = string
    name    = string
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
