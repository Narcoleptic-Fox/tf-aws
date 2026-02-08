variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name))
    error_message = "Name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "VPC CIDR must have a prefix between /16 and /24."
  }
}

variable "aws_region" {
  description = "AWS region for VPC endpoints"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region (e.g., us-east-1, eu-west-1)."
  }
}

variable "az_count" {
  description = "Number of availability zones to use (2-3 recommended)"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "AZ count must be between 2 and 6."
  }
}

variable "subnet_newbits" {
  description = "Number of additional bits for subnet CIDR calculation (8 = /24 subnets from /16 VPC)"
  type        = number
  default     = 8

  validation {
    condition     = var.subnet_newbits >= 4 && var.subnet_newbits <= 12
    error_message = "Subnet newbits must be between 4 and 12."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway(s) for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost savings, less HA)"
  type        = bool
  default     = false
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign public IPs in public subnets"
  type        = bool
  default     = true
}

variable "create_database_subnets" {
  description = "Create isolated database subnets with no internet access"
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Create S3 gateway endpoint (no additional charges)"
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Create DynamoDB gateway endpoint (no additional charges)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
