variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$", var.domain_name))
    error_message = "Domain name must be a valid DNS name."
  }
}

variable "create_public_zone" {
  description = "Create a public hosted zone"
  type        = bool
  default     = false
}

variable "create_private_zone" {
  description = "Create a private hosted zone"
  type        = bool
  default     = false
}

variable "private_zone_name" {
  description = "Name for private zone (defaults to domain_name)"
  type        = string
  default     = null
}

variable "existing_zone_id" {
  description = "Existing zone ID to use for records (if not creating zones)"
  type        = string
  default     = null
}

variable "zone_comment" {
  description = "Comment for the hosted zone"
  type        = string
  default     = "Managed by Terraform"
}

variable "force_destroy" {
  description = "Force destroy zone even if it contains records"
  type        = bool
  default     = false
}

variable "private_zone_vpcs" {
  description = "List of VPCs to associate with private zone"
  type = list(object({
    vpc_id     = string
    vpc_region = optional(string)
  }))
  default = []
}

variable "additional_vpc_associations" {
  description = "Additional VPCs to associate with the private zone after creation"
  type = map(object({
    vpc_id     = string
    vpc_region = optional(string)
  }))
  default = {}
}

variable "records" {
  description = "Map of DNS records to create"
  type = map(object({
    name      = string
    type      = string
    zone_type = optional(string, "public") # "public" or "private"
    ttl       = optional(number, 300)
    records   = optional(list(string))
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, true)
    }))
    set_identifier  = optional(string)
    health_check    = optional(string)
    allow_overwrite = optional(bool, false)
    weighted = optional(object({
      weight = number
    }))
    latency = optional(object({
      region = string
    }))
    failover = optional(object({
      type = string # PRIMARY or SECONDARY
    }))
    geolocation = optional(object({
      continent   = optional(string)
      country     = optional(string)
      subdivision = optional(string)
    }))
  }))
  default = {}

  # Example:
  # records = {
  #   "www" = {
  #     name    = "www.example.com"
  #     type    = "A"
  #     records = ["1.2.3.4"]
  #   }
  #   "api-alias" = {
  #     name = "api.example.com"
  #     type = "A"
  #     alias = {
  #       name    = "my-alb-123.us-east-1.elb.amazonaws.com"
  #       zone_id = "Z35SXDOTRQ7X7K"
  #     }
  #   }
  # }
}

variable "health_checks" {
  description = "Map of health checks to create"
  type = map(object({
    type              = string # HTTP, HTTPS, TCP, HTTP_STR_MATCH, HTTPS_STR_MATCH, CALCULATED, CLOUDWATCH_METRIC
    fqdn              = optional(string)
    ip_address        = optional(string)
    port              = optional(number)
    resource_path     = optional(string, "/")
    request_interval  = optional(number, 30)
    failure_threshold = optional(number, 3)
    enable_sni        = optional(bool)
    search_string     = optional(string)
    regions           = optional(list(string))
    invert            = optional(bool, false)
    disabled          = optional(bool, false)
    # For CALCULATED type
    child_healthchecks          = optional(list(string))
    child_health_threshold      = optional(number)
    insufficient_data_status    = optional(string) # Healthy, Unhealthy, LastKnownStatus
    # For CLOUDWATCH_METRIC type
    cloudwatch_alarm_name   = optional(string)
    cloudwatch_alarm_region = optional(string)
  }))
  default = {}

  # Example:
  # health_checks = {
  #   "api-health" = {
  #     type          = "HTTPS"
  #     fqdn          = "api.example.com"
  #     port          = 443
  #     resource_path = "/health"
  #   }
  # }
}

variable "enable_query_logging" {
  description = "Enable DNS query logging to CloudWatch"
  type        = bool
  default     = false
}

variable "query_log_group_arn" {
  description = "CloudWatch Log Group ARN for query logging"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
