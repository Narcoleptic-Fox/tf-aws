variable "name" {
  description = "Name for the EC2 instance and related resources"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name))
    error_message = "Name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string

  validation {
    condition     = can(regex("^ami-[a-f0-9]{8,17}$", var.ami_id))
    error_message = "AMI ID must be a valid format (ami-xxxxxxxx)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a valid format (e.g., t3.micro, m5.large)."
  }
}

variable "vpc_id" {
  description = "VPC ID where the instance will be launched"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid format."
  }
}

variable "subnet_id" {
  description = "Subnet ID for the instance (required if create_instance is true)"
  type        = string
  default     = null
}

variable "create_instance" {
  description = "Create an EC2 instance (set false if using Auto Scaling only)"
  type        = bool
  default     = true
}

variable "associate_public_ip" {
  description = "Associate a public IP address (not recommended for production)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# EBS Configuration
# -----------------------------------------------------------------------------

variable "root_device_name" {
  description = "Root device name (varies by AMI)"
  type        = string
  default     = "/dev/xvda"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 16384
    error_message = "Root volume size must be between 8 and 16384 GB."
  }
}

variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be gp2, gp3, io1, or io2."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS encryption (uses AWS managed key if null)"
  type        = string
  default     = null
}

variable "additional_volumes" {
  description = "Additional EBS volumes to attach"
  type = list(object({
    device_name           = string
    size                  = number
    type                  = optional(string, "gp3")
    iops                  = optional(number)
    throughput            = optional(number)
    delete_on_termination = optional(bool, true)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Security Group Rules
# -----------------------------------------------------------------------------

variable "ingress_rules" {
  description = "Map of ingress rules to add to security group"
  type = map(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    description              = string
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
    prefix_list_ids          = optional(list(string))
  }))
  default = {}

  # Example:
  # ingress_rules = {
  #   "app" = {
  #     from_port                = 8080
  #     to_port                  = 8080
  #     protocol                 = "tcp"
  #     description              = "Application port from ALB"
  #     source_security_group_id = "sg-12345678"
  #   }
  # }
}

variable "allow_all_egress" {
  description = "Allow all outbound traffic (false = HTTPS only for AWS services)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# IAM Configuration
# -----------------------------------------------------------------------------

variable "enable_cloudwatch_agent" {
  description = "Attach CloudWatch agent policy to instance role"
  type        = bool
  default     = true
}

variable "additional_policy_arns" {
  description = "List of additional IAM policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "custom_policy_json" {
  description = "Custom IAM policy JSON to attach inline"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Monitoring and Instance Options
# -----------------------------------------------------------------------------

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (1-minute intervals)"
  type        = bool
  default     = false
}

variable "user_data_base64" {
  description = "Base64-encoded user data script"
  type        = string
  default     = null
}

variable "cpu_credits" {
  description = "CPU credits option for T instances (standard or unlimited)"
  type        = string
  default     = null

  validation {
    condition     = var.cpu_credits == null || contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "CPU credits must be 'standard' or 'unlimited'."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
