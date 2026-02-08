# RDS Module

Creates a secure RDS instance following AWS security best practices.

## Security Features (Enforced)

- ✅ **Encryption at rest** — Always enabled, KMS optional
- ✅ **Encryption in transit** — SSL enforced via parameter group
- ✅ **No public access** — `publicly_accessible = false` hardcoded
- ✅ **Minimum 7-day backups** — Enforced regardless of input
- ✅ **Performance Insights** — Enabled by default
- ✅ **Enhanced monitoring** — 60-second intervals by default
- ✅ **IAM authentication** — Enabled by default
- ✅ **Deletion protection** — Enabled by default

## Usage

### Basic PostgreSQL

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

module "database" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/rds"

  name_prefix = module.naming.prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.database_subnet_ids

  engine         = "postgres"
  engine_version = "16.1"
  instance_class = "db.t3.medium"

  db_name  = "myapp"
  username = "admin"
  password = var.db_password  # Use Secrets Manager in production

  allowed_security_group_id = module.app.security_group_id

  tags = module.tags.common_tags
}
```

### Production MySQL with Multi-AZ

```hcl
module "database" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/rds"

  name_prefix = "myapp-prod"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.database_subnet_ids

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.r6g.large"
  
  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"

  db_name  = "myapp"
  username = "admin"
  password = var.db_password

  # High availability
  multi_az = true

  # Security
  kms_key_id = module.encryption.kms_key_arn

  # Monitoring
  monitoring_interval = 15
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  # Alarms
  alarm_actions = [aws_sns_topic.alerts.arn]

  allowed_security_group_id = module.app.security_group_id

  tags = module.tags.common_tags
}
```

### With Custom Parameters

```hcl
module "database" {
  source = "github.com/Narcoleptic-Fox/tf-aws//storage/rds"

  name_prefix = "analytics"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.database_subnet_ids

  engine         = "postgres"
  engine_version = "16.1"
  instance_class = "db.r6g.xlarge"

  db_name  = "analytics"
  username = "admin"
  password = var.db_password

  parameters = [
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    },
    {
      name  = "log_statement"
      value = "ddl"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"  # Log queries > 1 second
    }
  ]

  allowed_security_group_id = module.app.security_group_id

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
| name_prefix | Prefix for resource names | `string` | n/a | yes |
| vpc_id | VPC ID for security group | `string` | n/a | yes |
| subnet_ids | Subnet IDs for DB subnet group | `list(string)` | n/a | yes |
| engine | Database engine (postgres, mysql, mariadb) | `string` | n/a | yes |
| engine_version | Engine version | `string` | n/a | yes |
| username | Master username | `string` | n/a | yes |
| password | Master password | `string` | n/a | yes |
| instance_class | Instance class | `string` | `"db.t3.micro"` | no |
| allocated_storage | Storage in GB | `number` | `20` | no |
| multi_az | Enable Multi-AZ | `bool` | `false` | no |
| kms_key_id | KMS key for encryption | `string` | `null` | no |
| deletion_protection | Enable deletion protection | `bool` | `true` | no |

See `variables.tf` for full list.

## Outputs

| Name | Description |
|------|-------------|
| endpoint | Database endpoint (host:port) |
| address | Database hostname |
| port | Database port |
| database_name | Database name |
| security_group_id | Security group ID |
| connection_string_postgres | PostgreSQL connection template |
| connection_string_mysql | MySQL connection template |

## Notes

- **Password management**: Use AWS Secrets Manager with rotation in production
- **IAM authentication**: Enabled by default, use `aws rds generate-db-auth-token`
- **SSL certificates**: Download from https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html
