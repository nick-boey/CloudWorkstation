variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-coder-workstation"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "australiaeast"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "coder_version" {
  description = "Coder server version"
  type        = string
  default     = "2.16.1"
}

variable "workspace_cpu" {
  description = "CPU cores for dev workspaces"
  type        = number
  default     = 2
}

variable "workspace_memory" {
  description = "Memory in GB for dev workspaces"
  type        = string
  default     = "8Gi"
}

variable "admin_email" {
  description = "Email of the primary admin user"
  type        = string
}

variable "coder_domain" {
  description = "Custom domain for Coder (optional, leave empty to use Azure-provided domain)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "CloudWorkstation"
    ManagedBy   = "Terraform"
  }
}
