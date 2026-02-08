# VPC Module

Production-ready VPC with public and private subnets.

## Features

- [ ] Multi-AZ deployment
- [ ] Public subnets with Internet Gateway
- [ ] Private subnets with NAT Gateway
- [ ] VPC endpoints for AWS services
- [ ] Flow logs (integrated with tf-security)
- [ ] DNS hostnames enabled

## Planned Inputs

| Name | Description |
|------|-------------|
| `name` | VPC name |
| `cidr` | VPC CIDR block |
| `availability_zones` | List of AZs |
| `private_subnets` | Private subnet CIDRs |
| `public_subnets` | Public subnet CIDRs |
| `enable_nat` | Create NAT gateways |
| `tags` | Resource tags |

## Planned Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `private_subnet_ids` | Private subnet IDs |
| `public_subnet_ids` | Public subnet IDs |
| `nat_gateway_ips` | NAT gateway public IPs |
