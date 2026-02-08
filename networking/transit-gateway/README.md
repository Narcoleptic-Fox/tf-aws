# Transit Gateway Module

Creates an AWS Transit Gateway for hub-and-spoke VPC connectivity with
route tables, VPC attachments, and cross-account sharing support.

## Features

- Transit Gateway with customizable BGP ASN
- Multiple route tables for traffic segmentation
- VPC attachments with flexible routing
- Static routes and blackhole routes
- Cross-account sharing via Resource Access Manager (RAM)

## Usage

### Basic Hub-and-Spoke

```hcl
module "tgw" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/transit-gateway"

  name        = "central-tgw"
  description = "Central Transit Gateway for VPC connectivity"

  # Use default route table for simple setups
  default_route_table_association = true
  default_route_table_propagation = true

  vpc_attachments = {
    prod-vpc = {
      vpc_id     = module.vpc_prod.vpc_id
      subnet_ids = module.vpc_prod.private_subnet_ids
    }
    dev-vpc = {
      vpc_id     = module.vpc_dev.vpc_id
      subnet_ids = module.vpc_dev.private_subnet_ids
    }
  }

  tags = {
    Environment = "shared"
  }
}
```

### Segmented Routing

```hcl
module "tgw" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/transit-gateway"

  name = "segmented-tgw"

  # Disable defaults for custom routing
  default_route_table_association = false
  default_route_table_propagation = false

  route_tables = {
    production = {}
    development = {}
    shared = {}
  }

  vpc_attachments = {
    prod-vpc = {
      vpc_id       = module.vpc_prod.vpc_id
      subnet_ids   = module.vpc_prod.private_subnet_ids
      route_table  = "production"
      propagate_to = ["shared"]  # Prod routes visible to shared
    }
    dev-vpc = {
      vpc_id       = module.vpc_dev.vpc_id
      subnet_ids   = module.vpc_dev.private_subnet_ids
      route_table  = "development"
      propagate_to = ["shared"]  # Dev routes visible to shared
    }
    shared-vpc = {
      vpc_id       = module.vpc_shared.vpc_id
      subnet_ids   = module.vpc_shared.private_subnet_ids
      route_table  = "shared"
      propagate_to = ["production", "development"]  # Shared visible to all
    }
  }

  tags = {
    Environment = "shared"
  }
}
```

### Cross-Account Sharing

```hcl
module "tgw" {
  source = "github.com/Narcoleptic-Fox/tf-aws//networking/transit-gateway"

  name = "shared-tgw"

  # Enable cross-account sharing
  enable_ram_sharing        = true
  allow_external_principals = false  # Stay within AWS Organization

  ram_principals = [
    "123456789012",  # Production account
    "234567890123",  # Development account
  ]

  # Auto-accept attachments from shared accounts
  auto_accept_shared_attachments = true

  tags = {
    Environment = "network"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name for the Transit Gateway | `string` | n/a | yes |
| description | Description | `string` | `"Managed by Terraform"` | no |
| amazon_side_asn | Private BGP ASN | `number` | `64512` | no |
| auto_accept_shared_attachments | Auto-accept shared attachments | `bool` | `false` | no |
| default_route_table_association | Auto-associate with default RT | `bool` | `true` | no |
| default_route_table_propagation | Auto-propagate to default RT | `bool` | `true` | no |
| dns_support | Enable DNS support | `bool` | `true` | no |
| route_tables | Map of route tables to create | `map(any)` | `{}` | no |
| vpc_attachments | Map of VPC attachments | `map(object)` | `{}` | no |
| static_routes | Map of static routes | `map(object)` | `{}` | no |
| enable_ram_sharing | Enable RAM sharing | `bool` | `false` | no |
| ram_principals | Principals to share with | `list(string)` | `[]` | no |
| tags | Tags to apply | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| transit_gateway_id | The ID of the Transit Gateway |
| transit_gateway_arn | The ARN of the Transit Gateway |
| route_table_ids | Map of route table names to IDs |
| vpc_attachment_ids | Map of VPC attachment names to IDs |
| ram_resource_share_arn | ARN of the RAM resource share |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Transit Gateway                         │
│                                                             │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │  Production   │  │  Development  │  │    Shared     │   │
│  │  Route Table  │  │  Route Table  │  │  Route Table  │   │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘   │
│          │                  │                  │           │
│  ┌───────▼───────┐  ┌───────▼───────┐  ┌───────▼───────┐   │
│  │   Prod VPC    │  │   Dev VPC     │  │  Shared VPC   │   │
│  │  Attachment   │  │  Attachment   │  │  Attachment   │   │
│  └───────────────┘  └───────────────┘  └───────────────┘   │
└─────────────────────────────────────────────────────────────┘
              │                  │                  │
              ▼                  ▼                  ▼
        ┌──────────┐      ┌──────────┐      ┌──────────┐
        │ Prod VPC │      │ Dev VPC  │      │Shared VPC│
        │10.1.0/16 │      │10.2.0/16 │      │10.0.0/16 │
        └──────────┘      └──────────┘      └──────────┘
```

## VPC Route Table Updates

Don't forget to add routes in your VPC route tables pointing to the TGW:

```hcl
resource "aws_route" "to_tgw" {
  route_table_id         = module.vpc.private_route_table_ids[0]
  destination_cidr_block = "10.0.0.0/8"  # All internal networks
  transit_gateway_id     = module.tgw.transit_gateway_id
}
```

## Security Considerations

- ✅ Use segmented route tables to isolate environments
- ✅ Blackhole routes block unwanted traffic
- ✅ RAM sharing stays within AWS Organization by default
- ⚠️ Review auto_accept_shared_attachments carefully
- ⚠️ Monitor cross-account traffic with VPC Flow Logs
