# VPC Module

Creates a production-ready VPC with public, private, and database subnets,
NAT gateways, and VPC endpoints for secure AWS service access.

## Features

- Multi-AZ deployment (2-6 AZs supported)
- Public subnets with Internet Gateway
- Private subnets with NAT Gateway(s)
- Isolated database subnets (no internet access)
- VPC endpoints for S3 and DynamoDB (gateway type - no charges)
- DNS hostnames and resolution enabled
- DB subnet group for RDS/Aurora

## Usage

```hcl
module "vpc" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/vpc"

  name       = "prod-vpc"
  vpc_cidr   = "10.0.0.0/16"
  aws_region = "us-east-1"

  az_count                = 3
  enable_nat_gateway      = true
  single_nat_gateway      = false  # HA: one NAT per AZ
  create_database_subnets = true

  # Gateway endpoints (no cost)
  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  tags = {
    Environment = "production"
    Project     = "my-app"
  }
}
```

## Cost Optimization

For development environments, use `single_nat_gateway = true` to reduce costs:

```hcl
module "vpc_dev" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/vpc"

  name               = "dev-vpc"
  vpc_cidr           = "10.1.0.0/16"
  aws_region         = "us-east-1"
  az_count           = 2
  single_nat_gateway = true  # Single NAT for cost savings

  tags = {
    Environment = "development"
  }
}
```

## Security with tf-security

Combine with VPC security module for enhanced protection:

```hcl
module "vpc" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/vpc"
  # ... config
}

module "vpc_security" {
  source = "github.com/Narcoleptic-Fox/tf-security//aws/vpc-security"

  vpc_id             = module.vpc.vpc_id
  enable_flow_logs   = true
  flow_logs_bucket   = "my-flow-logs-bucket"
  enable_dns_firewall = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name prefix for VPC resources | `string` | n/a | yes |
| vpc_cidr | CIDR block for the VPC | `string` | n/a | yes |
| aws_region | AWS region for VPC endpoints | `string` | n/a | yes |
| az_count | Number of availability zones | `number` | `3` | no |
| enable_nat_gateway | Enable NAT gateway(s) | `bool` | `true` | no |
| single_nat_gateway | Use single NAT gateway | `bool` | `false` | no |
| create_database_subnets | Create isolated DB subnets | `bool` | `true` | no |
| enable_s3_endpoint | Create S3 gateway endpoint | `bool` | `true` | no |
| enable_dynamodb_endpoint | Create DynamoDB gateway endpoint | `bool` | `true` | no |
| tags | Tags to apply | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr_block | The CIDR block of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| database_subnet_ids | List of database subnet IDs |
| database_subnet_group_name | Name of the DB subnet group |
| nat_gateway_ids | List of NAT Gateway IDs |
| availability_zones | List of availability zones used |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     VPC (10.0.0.0/16)                       │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Public Subnets (IGW route)                          │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │  AZ-a    │  │  AZ-b    │  │  AZ-c    │   NAT GW │   │
│  │  │10.0.0/24 │  │10.0.1/24 │  │10.0.2/24 │          │   │
│  │  └──────────┘  └──────────┘  └──────────┘          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Private Subnets (NAT route)                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │  AZ-a    │  │  AZ-b    │  │  AZ-c    │   App    │   │
│  │  │10.0.3/24 │  │10.0.4/24 │  │10.0.5/24 │  Servers │   │
│  │  └──────────┘  └──────────┘  └──────────┘          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Database Subnets (isolated - no internet)           │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │  AZ-a    │  │  AZ-b    │  │  AZ-c    │   RDS    │   │
│  │  │10.0.6/24 │  │10.0.7/24 │  │10.0.8/24 │          │   │
│  │  └──────────┘  └──────────┘  └──────────┘          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  VPC Endpoints: S3, DynamoDB (Gateway - no charges)        │
└─────────────────────────────────────────────────────────────┘
```

## Security Considerations

- ✅ Database subnets have no internet access
- ✅ Private subnets egress through NAT only
- ✅ VPC endpoints reduce traffic exposure
- ✅ DNS hostnames enable private DNS resolution
- ⚠️ Add VPC Flow Logs via tf-security/vpc-security module
- ⚠️ Add security groups via application modules
