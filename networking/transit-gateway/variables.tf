variable "name" {
  description = "Name for the Transit Gateway"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name))
    error_message = "Name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "description" {
  description = "Description for the Transit Gateway"
  type        = string
  default     = "Managed by Terraform"
}

variable "amazon_side_asn" {
  description = "Private ASN for the Amazon side of the TGW (64512-65534 or 4200000000-4294967294)"
  type        = number
  default     = 64512

  validation {
    condition = (
      (var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534) ||
      (var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294)
    )
    error_message = "ASN must be in range 64512-65534 or 4200000000-4294967294."
  }
}

variable "auto_accept_shared_attachments" {
  description = "Auto-accept shared attachments from other accounts"
  type        = bool
  default     = false
}

variable "default_route_table_association" {
  description = "Auto-associate attachments with default route table"
  type        = bool
  default     = true
}

variable "default_route_table_propagation" {
  description = "Auto-propagate routes to default route table"
  type        = bool
  default     = true
}

variable "dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "vpn_ecmp_support" {
  description = "Enable VPN ECMP (equal-cost multi-path) routing"
  type        = bool
  default     = true
}

variable "multicast_support" {
  description = "Enable multicast support"
  type        = bool
  default     = false
}

variable "route_tables" {
  description = "Map of route tables to create (key = name)"
  type        = map(any)
  default     = {}

  # Example:
  # route_tables = {
  #   production = {}
  #   development = {}
  #   shared = {}
  # }
}

variable "vpc_attachments" {
  description = "Map of VPC attachments"
  type = map(object({
    vpc_id                 = string
    subnet_ids             = list(string)
    dns_support            = optional(bool, true)
    ipv6_support           = optional(bool, false)
    appliance_mode_support = optional(bool, false)
    route_table            = optional(string)
    propagate_to           = optional(list(string), [])
  }))
  default = {}

  # Example:
  # vpc_attachments = {
  #   prod-vpc = {
  #     vpc_id      = "vpc-12345"
  #     subnet_ids  = ["subnet-a", "subnet-b"]
  #     route_table = "production"
  #     propagate_to = ["shared"]
  #   }
  # }
}

variable "static_routes" {
  description = "Map of static routes"
  type = map(object({
    destination_cidr = string
    route_table      = string
    attachment       = optional(string)
    blackhole        = optional(bool, false)
  }))
  default = {}

  # Example:
  # static_routes = {
  #   to-onprem = {
  #     destination_cidr = "10.100.0.0/16"
  #     route_table      = "production"
  #     attachment       = "vpn-attachment"
  #   }
  #   blackhole-rfc1918 = {
  #     destination_cidr = "192.168.0.0/16"
  #     route_table      = "production"
  #     blackhole        = true
  #   }
  # }
}

variable "enable_ram_sharing" {
  description = "Enable Resource Access Manager sharing for cross-account"
  type        = bool
  default     = false
}

variable "allow_external_principals" {
  description = "Allow sharing with accounts outside the organization"
  type        = bool
  default     = false
}

variable "ram_principals" {
  description = "List of principals (account IDs or org ARNs) to share with"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for p in var.ram_principals : can(regex("^[0-9]{12}$", p)) || can(regex("^arn:aws:organizations::", p))
    ])
    error_message = "Principals must be 12-digit account IDs or organization ARNs."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
