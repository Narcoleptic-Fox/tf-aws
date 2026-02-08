# Route 53 Module

Manages Route 53 hosted zones, DNS records, and health checks for
public and private DNS resolution.

## Features

- Public and private hosted zones
- All record types (A, AAAA, CNAME, ALIAS, MX, TXT, etc.)
- Health checks with various protocols
- Routing policies (weighted, latency, failover, geolocation)
- DNS query logging
- VPC associations for private zones

## Usage

### Public Zone with Records

```hcl
module "dns" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/route53"

  domain_name        = "example.com"
  create_public_zone = true

  records = {
    # Simple A record
    "www" = {
      name    = "www.example.com"
      type    = "A"
      ttl     = 300
      records = ["1.2.3.4"]
    }

    # ALIAS to ALB
    "api" = {
      name = "api.example.com"
      type = "A"
      alias = {
        name    = "my-alb-123456.us-east-1.elb.amazonaws.com"
        zone_id = "Z35SXDOTRQ7X7K"  # ALB hosted zone ID
      }
    }

    # ALIAS to CloudFront
    "cdn" = {
      name = "cdn.example.com"
      type = "A"
      alias = {
        name    = "d111111abcdef8.cloudfront.net"
        zone_id = "Z2FDTNDATAQYW2"  # CloudFront zone ID
      }
    }

    # MX record
    "mx" = {
      name    = "example.com"
      type    = "MX"
      ttl     = 3600
      records = ["10 mail.example.com"]
    }

    # TXT record (SPF)
    "spf" = {
      name    = "example.com"
      type    = "TXT"
      ttl     = 3600
      records = ["\"v=spf1 include:_spf.google.com ~all\""]
    }
  }

  tags = {
    Project = "my-app"
  }
}
```

### Private Zone for VPC

```hcl
module "internal_dns" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/route53"

  domain_name         = "internal.example.com"
  create_private_zone = true

  private_zone_vpcs = [
    {
      vpc_id     = module.vpc.vpc_id
      vpc_region = "us-east-1"
    }
  ]

  records = {
    "db" = {
      name      = "db.internal.example.com"
      type      = "CNAME"
      zone_type = "private"
      ttl       = 60
      records   = [module.rds.endpoint]
    }

    "cache" = {
      name      = "cache.internal.example.com"
      type      = "CNAME"
      zone_type = "private"
      ttl       = 60
      records   = [module.elasticache.endpoint]
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### Health Checks with Failover

```hcl
module "dns_failover" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/route53"

  domain_name        = "example.com"
  create_public_zone = true

  health_checks = {
    "api-primary" = {
      type          = "HTTPS"
      fqdn          = "api-primary.example.com"
      port          = 443
      resource_path = "/health"
    }
  }

  records = {
    "api-primary" = {
      name           = "api.example.com"
      type           = "A"
      set_identifier = "primary"
      records        = ["1.2.3.4"]
      ttl            = 60
      health_check   = "api-primary"
      failover = {
        type = "PRIMARY"
      }
    }

    "api-secondary" = {
      name           = "api.example.com"
      type           = "A"
      set_identifier = "secondary"
      records        = ["5.6.7.8"]
      ttl            = 60
      failover = {
        type = "SECONDARY"
      }
    }
  }
}
```

### Weighted Routing

```hcl
module "dns_weighted" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/route53"

  domain_name      = "example.com"
  existing_zone_id = "Z1234567890ABC"  # Use existing zone

  records = {
    "api-90" = {
      name           = "api.example.com"
      type           = "A"
      set_identifier = "region-1"
      records        = ["1.2.3.4"]
      weighted = {
        weight = 90
      }
    }

    "api-10" = {
      name           = "api.example.com"
      type           = "A"
      set_identifier = "region-2"
      records        = ["5.6.7.8"]
      weighted = {
        weight = 10
      }
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain_name | Domain name for the zone | `string` | n/a | yes |
| create_public_zone | Create public hosted zone | `bool` | `false` | no |
| create_private_zone | Create private hosted zone | `bool` | `false` | no |
| existing_zone_id | Use existing zone ID | `string` | `null` | no |
| private_zone_vpcs | VPCs for private zone | `list(object)` | `[]` | no |
| records | Map of DNS records | `map(object)` | `{}` | no |
| health_checks | Map of health checks | `map(object)` | `{}` | no |
| enable_query_logging | Enable DNS query logging | `bool` | `false` | no |
| tags | Tags to apply | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| public_zone_id | ID of the public hosted zone |
| public_zone_name_servers | Name servers for public zone |
| private_zone_id | ID of the private hosted zone |
| record_names | Map of record keys to FQDNs |
| health_check_ids | Map of health check names to IDs |
| zone_id | The zone ID (public or private) |

## Common ALB/CloudFront Zone IDs

For ALIAS records, you need the hosted zone ID of the target:

| Service | Region | Hosted Zone ID |
|---------|--------|----------------|
| ALB | us-east-1 | Z35SXDOTRQ7X7K |
| ALB | us-west-2 | Z1H1FL5HABSF5 |
| ALB | eu-west-1 | Z32O12XQLNTSW2 |
| CloudFront | Global | Z2FDTNDATAQYW2 |
| S3 Website | us-east-1 | Z3AQBSTGFYJSTF |
| API Gateway | us-east-1 | Z1UJRXOUMOOFQ8 |

## Security Considerations

- ✅ Private zones are only accessible within associated VPCs
- ✅ Health checks can detect endpoint failures
- ✅ Query logging enables audit trails
- ⚠️ DNSSEC should be enabled for public zones (manual step)
- ⚠️ Consider domain lock for registrar-level protection
