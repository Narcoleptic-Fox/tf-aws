# Lambda Module

Serverless function baseline with best practices.

## Features

- [ ] VPC-connected or public
- [ ] Environment variable encryption
- [ ] X-Ray tracing
- [ ] CloudWatch Logs integration
- [ ] Dead letter queue
- [ ] Provisioned concurrency option
- [ ] IAM role from tf-security

## Usage (Coming Soon)

```hcl
module "lambda" {
  source = "./modules/tf-aws/compute/lambda"
  
  name           = "${module.naming.lambda_name}-processor"
  runtime        = "python3.11"
  handler        = "main.handler"
  source_path    = "./src/processor"
  
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  
  tags = module.tags.common_tags
}
```
