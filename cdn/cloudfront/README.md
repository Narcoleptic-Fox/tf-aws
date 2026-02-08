# CloudFront Distribution Module

Creates a secure CloudFront distribution following AWS best practices.

## Security Features (Enforced)

- ✅ **HTTPS only** — HTTP automatically redirects to HTTPS
- ✅ **Modern TLS** — TLSv1.2_2021 minimum by default
- ✅ **Origin Access Control** — For S3 origins (replaces legacy OAI)
- ✅ **Origin HTTPS** — ALB/custom origins use HTTPS by default
- ✅ **WAF ready** — Simple integration via `web_acl_id`

## Usage

### Static S3 Website

```hcl
module "naming" {
  source      = "github.com/Narcoleptic-Fox/tf-security//core/naming"
  project     = "myapp"
  environment = "prod"
  region      = "us-east-1"
}

module "tags" {
  source      = "github.com/Narcoleptic-Fox/tf-security//core/tagging"
  project     = "myapp"
  environment = "prod"
  owner       = "platform"
  cost_center = "engineering"
}

module "cdn" {
  source = "github.com/Narcoleptic-Fox/tf-aws//cdn/cloudfront"

  name                = "${module.naming.prefix}-cdn"
  default_root_object = "index.html"

  s3_origin = {
    bucket_name                 = module.website_bucket.bucket_name
    bucket_arn                  = module.website_bucket.bucket_arn
    bucket_regional_domain_name = module.website_bucket.bucket_regional_domain_name
  }

  # Custom domain with ACM certificate
  aliases             = ["www.example.com"]
  acm_certificate_arn = aws_acm_certificate.main.arn

  # SPA error handling
  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    },
    {
      error_code         = 403
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]

  # Route53 alias record
  route53_records = {
    www = {
      zone_id = data.aws_route53_zone.main.zone_id
      name    = "www.example.com"
    }
  }

  tags = module.tags.common_tags
}
```

### ALB Origin with WAF

```hcl
module "cdn" {
  source = "github.com/Narcoleptic-Fox/tf-aws//cdn/cloudfront"

  name = "api-cdn"

  alb_origin = {
    domain_name     = module.alb.dns_name
    protocol_policy = "https-only"
    
    # Add a secret header to verify requests came through CloudFront
    custom_headers = {
      "X-Origin-Verify" = var.cloudfront_secret
    }
  }

  # Enable WAF
  web_acl_id = aws_wafv2_web_acl.main.arn

  # API-style caching
  default_cache_behavior = {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    
    # Use managed cache policies
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # Custom domain
  aliases             = ["api.example.com"]
  acm_certificate_arn = aws_acm_certificate.api.arn

  tags = module.tags.common_tags
}

# Managed policies
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}
```

### Multiple Origins with Path Patterns

```hcl
module "cdn" {
  source = "github.com/Narcoleptic-Fox/tf-aws//cdn/cloudfront"

  name = "multi-origin-cdn"

  # Static assets from S3
  s3_origin = {
    bucket_name                 = module.assets_bucket.bucket_name
    bucket_arn                  = module.assets_bucket.bucket_arn
    bucket_regional_domain_name = module.assets_bucket.bucket_regional_domain_name
  }

  # API from ALB
  alb_origin = {
    domain_name = module.api_alb.dns_name
  }

  # Default to S3
  default_cache_behavior = {
    compress        = true
    cache_policy_id = data.aws_cloudfront_cache_policy.optimized.id
  }

  # API paths go to ALB
  ordered_cache_behaviors = [
    {
      path_pattern     = "/api/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "ALB-${module.api_alb.dns_name}"
      cache_policy_id  = data.aws_cloudfront_cache_policy.disabled.id
    }
  ]

  aliases             = ["example.com"]
  acm_certificate_arn = aws_acm_certificate.main.arn

  tags = module.tags.common_tags
}
```

### With Access Logging

```hcl
module "cdn" {
  source = "github.com/Narcoleptic-Fox/tf-aws//cdn/cloudfront"

  name = "logged-cdn"

  s3_origin = {
    bucket_name                 = module.website.bucket_name
    bucket_arn                  = module.website.bucket_arn
    bucket_regional_domain_name = module.website.bucket_regional_domain_name
  }

  # Enable access logging
  logging_bucket          = "${module.logs_bucket.bucket_name}.s3.amazonaws.com"
  logging_prefix          = "cloudfront/"
  logging_include_cookies = false

  tags = module.tags.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Distribution name | `string` | n/a | yes |
| s3_origin | S3 origin configuration | `object` | `null` | no |
| alb_origin | ALB origin configuration | `object` | `null` | no |
| custom_origins | Custom origins | `map(object)` | `{}` | no |
| aliases | Custom domain names | `list(string)` | `[]` | no |
| acm_certificate_arn | ACM certificate (us-east-1) | `string` | `null` | no |
| web_acl_id | WAF web ACL ARN | `string` | `null` | no |
| default_cache_behavior | Default behavior config | `object` | `{}` | no |
| ordered_cache_behaviors | Path-based behaviors | `list(object)` | `[]` | no |

See `variables.tf` for full list.

## Outputs

| Name | Description |
|------|-------------|
| distribution_id | CloudFront distribution ID |
| distribution_arn | Distribution ARN |
| distribution_domain_name | CloudFront domain (*.cloudfront.net) |
| distribution_url | Full HTTPS URL |

## Notes

- **ACM Certificate**: Must be in `us-east-1` for CloudFront
- **Origin Access Control**: Automatically created for S3 origins (replaces OAI)
- **Cache Policies**: Use AWS managed policies when possible
- **WAF**: Create web ACL in `us-east-1` for CloudFront scope
