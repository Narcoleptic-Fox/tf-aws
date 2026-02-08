/**
 * # EC2 Baseline Module
 *
 * Creates hardened EC2 instances following AWS security best practices.
 *
 * Security features:
 * - IMDSv2 enforced (token-based metadata)
 * - SSM Session Manager (no SSH keys needed)
 * - EBS encryption with KMS
 * - Instance profile with minimal permissions
 * - No public IP by default
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  name = var.name
}

# -----------------------------------------------------------------------------
# IAM Role and Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_role" "instance" {
  name        = "${local.name}-instance-role"
  description = "EC2 instance role for ${local.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# SSM Core - Required for Session Manager
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent (optional)
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Additional managed policies
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.instance.name
  policy_arn = each.value
}

# Custom inline policy
resource "aws_iam_role_policy" "custom" {
  count = var.custom_policy_json != null ? 1 : 0

  name   = "custom-permissions"
  role   = aws_iam_role.instance.id
  policy = var.custom_policy_json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name}-instance-profile"
  role = aws_iam_role.instance.name

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "instance" {
  name_prefix = "${local.name}-"
  vpc_id      = var.vpc_id
  description = "Security group for ${local.name} EC2 instance"

  # Egress to AWS services (SSM, CloudWatch, etc.)
  egress {
    description = "HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional: Allow all egress
  dynamic "egress" {
    for_each = var.allow_all_egress ? [1] : []
    content {
      description = "All outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = merge(var.tags, {
    Name = "${local.name}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Additional ingress rules
resource "aws_security_group_rule" "ingress" {
  for_each = var.ingress_rules

  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  security_group_id = aws_security_group.instance.id
  description       = each.value.description

  # Source - either CIDR, security group, or prefix list
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_security_group_id", null)
  prefix_list_ids          = lookup(each.value, "prefix_list_ids", null)
}

# -----------------------------------------------------------------------------
# Launch Template (for Auto Scaling or single instance)
# -----------------------------------------------------------------------------

resource "aws_launch_template" "main" {
  name        = local.name
  description = "Launch template for ${local.name}"

  image_id      = var.ami_id
  instance_type = var.instance_type

  # IMDSv2 enforced
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 only
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Networking
  network_interfaces {
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.instance.id]
    delete_on_termination       = true
  }

  # IAM instance profile
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  # EBS root volume
  block_device_mappings {
    device_name = var.root_device_name

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  # Additional EBS volumes
  dynamic "block_device_mappings" {
    for_each = var.additional_volumes
    content {
      device_name = block_device_mappings.value.device_name

      ebs {
        volume_size           = block_device_mappings.value.size
        volume_type           = lookup(block_device_mappings.value, "type", "gp3")
        encrypted             = true
        kms_key_id            = var.kms_key_arn
        iops                  = lookup(block_device_mappings.value, "iops", null)
        throughput            = lookup(block_device_mappings.value, "throughput", null)
        delete_on_termination = lookup(block_device_mappings.value, "delete_on_termination", true)
      }
    }
  }

  # Monitoring
  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # User data
  user_data = var.user_data_base64

  # Credit specification for T instances
  dynamic "credit_specification" {
    for_each = var.cpu_credits != null ? [1] : []
    content {
      cpu_credits = var.cpu_credits
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = local.name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${local.name}-volume"
    })
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EC2 Instance (optional - when not using Auto Scaling)
# -----------------------------------------------------------------------------

resource "aws_instance" "main" {
  count = var.create_instance ? 1 : 0

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  subnet_id = var.subnet_id

  tags = merge(var.tags, {
    Name = local.name
  })
}
