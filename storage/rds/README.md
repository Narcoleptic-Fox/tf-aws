# RDS Module

Managed database with encryption and automated backups.

## Features

- [ ] Multi-AZ deployment
- [ ] KMS encryption at rest
- [ ] SSL in transit
- [ ] Automated backups
- [ ] Parameter groups
- [ ] Subnet groups
- [ ] Security group integration
- [ ] Performance Insights

## Supported Engines

- PostgreSQL
- MySQL
- MariaDB

## Usage (Coming Soon)

```hcl
module "database" {
  source = "./modules/tf-aws/storage/rds"
  
  name           = module.naming.rds_name
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.medium"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  kms_key_arn = module.encryption.rds_key_arn
  
  tags = module.tags.common_tags
}
```
