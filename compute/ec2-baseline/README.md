# EC2 Baseline Module

Creates hardened EC2 instances following AWS security best practices
with SSM Session Manager access (no SSH keys required).

## Features

- **IMDSv2 enforced** - Token-based instance metadata only
- **SSM Session Manager** - Secure shell access without SSH keys
- **EBS encryption** - All volumes encrypted with KMS
- **No public IP** - Private subnet deployment by default
- **Minimal IAM permissions** - Least-privilege instance role
- **Launch template** - Ready for Auto Scaling or standalone use

## Usage

### Basic Instance

```hcl
module "ec2" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ec2-baseline"

  name          = "web-server"
  ami_id        = "ami-0123456789abcdef0"
  instance_type = "t3.small"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]

  root_volume_size = 30
  kms_key_arn      = module.kms.key_arn

  tags = {
    Environment = "production"
    Application = "web"
  }
}
```

### Instance with Ingress Rules

```hcl
module "app_server" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ec2-baseline"

  name          = "app-server"
  ami_id        = data.aws_ami.amazon_linux_2023.id
  instance_type = "m5.large"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]

  ingress_rules = {
    "app" = {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      description              = "Application port from ALB"
      source_security_group_id = module.alb.security_group_id
    }
  }

  additional_volumes = [
    {
      device_name = "/dev/sdf"
      size        = 100
      type        = "gp3"
      throughput  = 125
    }
  ]

  tags = {
    Environment = "production"
  }
}
```

### Launch Template Only (for Auto Scaling)

```hcl
module "asg_template" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ec2-baseline"

  name            = "web-asg"
  ami_id          = data.aws_ami.amazon_linux_2023.id
  instance_type   = "t3.medium"
  vpc_id          = module.vpc.vpc_id
  create_instance = false  # Only create launch template

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
  EOF
  )

  tags = {
    Environment = "production"
  }
}

# Use with Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = module.vpc.private_subnet_ids

  launch_template {
    id      = module.asg_template.launch_template_id
    version = "$Latest"
  }
}
```

### With Custom IAM Policy

```hcl
module "ec2" {
  source = "github.com/Narcoleptic-Fox/tf-aws//compute/ec2-baseline"

  name          = "s3-processor"
  ami_id        = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${module.s3.bucket_arn}/*"
      }
    ]
  })

  tags = {
    Environment = "production"
  }
}
```

## Security with tf-security

Combine with IAM baseline for consistent role patterns:

```hcl
module "iam_baseline" {
  source = "github.com/Narcoleptic-Fox/tf-security//aws/iam-baseline"

  name_prefix         = "my-app"
  create_ec2_ssm_role = true
  enable_ec2_cloudwatch = true
}

# Reference the profile from tf-security instead
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name for resources | `string` | n/a | yes |
| ami_id | AMI ID | `string` | n/a | yes |
| instance_type | Instance type | `string` | `"t3.micro"` | no |
| vpc_id | VPC ID | `string` | n/a | yes |
| subnet_id | Subnet ID | `string` | `null` | no |
| create_instance | Create instance (vs template only) | `bool` | `true` | no |
| root_volume_size | Root volume size (GB) | `number` | `20` | no |
| kms_key_arn | KMS key for EBS encryption | `string` | `null` | no |
| ingress_rules | Security group ingress rules | `map(object)` | `{}` | no |
| enable_cloudwatch_agent | Attach CloudWatch policy | `bool` | `true` | no |
| additional_policy_arns | Additional IAM policies | `list(string)` | `[]` | no |
| user_data_base64 | Base64 user data | `string` | `null` | no |
| tags | Tags to apply | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID |
| instance_private_ip | Private IP address |
| launch_template_id | Launch template ID |
| security_group_id | Security group ID |
| iam_role_arn | IAM role ARN |
| instance_profile_arn | Instance profile ARN |

## Connecting via SSM Session Manager

No SSH keys needed! Connect via AWS Console or CLI:

```bash
# Using AWS CLI
aws ssm start-session --target i-1234567890abcdef0

# Or use the console: EC2 → Instance → Connect → Session Manager
```

## Security Considerations

- ✅ IMDSv2 enforced (no v1 metadata access)
- ✅ EBS volumes encrypted by default
- ✅ SSM Session Manager (no SSH keys to manage)
- ✅ No public IP by default
- ✅ Security group with minimal egress
- ⚠️ Add ingress rules only from trusted sources
- ⚠️ Use CMK for KMS encryption in production
