# EC2 Baseline Module

Hardened EC2 instance with SSM and security best practices.

## Features

- [ ] IMDSv2 required
- [ ] SSM Session Manager (no SSH keys)
- [ ] EBS encryption by default
- [ ] CloudWatch agent pre-installed
- [ ] Security group integration
- [ ] User data templating

## Usage (Coming Soon)

```hcl
module "ec2" {
  source = "./modules/tf-aws/compute/ec2-baseline"
  
  name          = "${module.naming.ec2_name}-web"
  instance_type = "t3.medium"
  subnet_id     = module.vpc.private_subnet_ids[0]
  ami_id        = data.aws_ami.amazon_linux.id
  
  security_group_ids = [module.vpc_security.app_sg_id]
  tags               = module.tags.common_tags
}
```
