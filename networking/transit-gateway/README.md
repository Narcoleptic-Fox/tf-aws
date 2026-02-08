# Transit Gateway Module

Multi-VPC and multi-account connectivity hub.

## Features

- [ ] Transit Gateway with auto-accept
- [ ] VPC attachments
- [ ] Route table associations
- [ ] Cross-account sharing
- [ ] VPN attachment support

## Usage (Coming Soon)

```hcl
module "tgw" {
  source = "./modules/tf-aws/networking/transit-gateway"
  
  name        = module.naming.prefix
  vpc_ids     = [module.vpc.vpc_id]
  route_cidrs = ["10.0.0.0/8"]
  tags        = module.tags.common_tags
}
```
