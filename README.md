# 🦊 tf-aws

**Terraform AWS infrastructure modules**

Part of the [Narcoleptic Fox](https://github.com/Narcoleptic-Fox) infrastructure toolkit.

## Overview

Production-ready AWS infrastructure patterns:
- **Networking** — VPC, Transit Gateway, Route53
- **Compute** — EC2, ECS, Lambda
- **Storage** — S3, RDS
- **CDN** — CloudFront with WAF

Pairs with [tf-security](https://github.com/Narcoleptic-Fox/tf-security) for security baselines.

## Quick Start

Add as a git submodule:

```bash
git submodule add https://github.com/Narcoleptic-Fox/tf-aws.git modules/tf-aws
git submodule add https://github.com/Narcoleptic-Fox/tf-security.git modules/tf-security
```

## Modules

### Networking

| Module | Description |
|--------|-------------|
| [`networking/vpc`](./networking/vpc/) | VPC with public/private subnets |
| [`networking/transit-gateway`](./networking/transit-gateway/) | Multi-VPC connectivity |
| [`networking/route53`](./networking/route53/) | DNS zones and records |

### Compute

| Module | Description |
|--------|-------------|
| [`compute/ec2-baseline`](./compute/ec2-baseline/) | Hardened EC2 with SSM |
| [`compute/ecs-cluster`](./compute/ecs-cluster/) | Container orchestration |
| [`compute/lambda`](./compute/lambda/) | Serverless baseline |

### Storage

| Module | Description |
|--------|-------------|
| [`storage/s3-bucket`](./storage/s3-bucket/) | Encrypted, versioned, logged |
| [`storage/rds`](./storage/rds/) | RDS with encryption |

### CDN

| Module | Description |
|--------|-------------|
| [`cdn/cloudfront`](./cdn/cloudfront/) | CDN + WAF integration |

## Usage Example

```hcl
module "naming" {
  source      = "./modules/tf-security/core/naming"
  project     = "mousing"
  environment = "prod"
  region      = "us-east-1"
}

module "tags" {
  source      = "./modules/tf-security/core/tagging"
  project     = "mousing"
  environment = "prod"
  owner       = "platform"
  cost_center = "engineering"
}

module "vpc" {
  source = "./modules/tf-aws/networking/vpc"

  name               = module.naming.vpc_name
  cidr               = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  tags = module.tags.common_tags
}
```

## Related Repos

- [tf-security](https://github.com/Narcoleptic-Fox/tf-security) — Security baseline modules
- [tf-azure](https://github.com/Narcoleptic-Fox/tf-azure) — Azure infrastructure modules

## License

MIT — See [LICENSE](./LICENSE)
