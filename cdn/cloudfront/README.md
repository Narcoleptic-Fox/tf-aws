# CloudFront Module

CDN distribution with WAF integration.

## Features

- [ ] S3 or ALB origin
- [ ] HTTPS only
- [ ] Custom domain with ACM
- [ ] WAF WebACL attachment
- [ ] Response headers policy
- [ ] Cache behaviors
- [ ] Origin access identity
- [ ] Real-time logs

## Usage (Coming Soon)

```hcl
module "cdn" {
  source = "./modules/tf-aws/cdn/cloudfront"
  
  name              = module.naming.prefix
  origin_bucket     = module.static_bucket.bucket_regional_domain_name
  origin_bucket_arn = module.static_bucket.arn
  
  domain_name      = "cdn.example.com"
  certificate_arn  = aws_acm_certificate.main.arn
  waf_web_acl_arn  = aws_wafv2_web_acl.main.arn
  
  tags = module.tags.common_tags
}
```
