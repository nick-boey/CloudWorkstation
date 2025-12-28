# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "CloudWorkstation"
    ManagedBy = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# Virtual Network Configuration
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vm_subnet_prefix" {
  description = "VM subnet address prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aci_subnet_prefix" {
  description = "ACI subnet address prefix"
  type        = string
  default     = "10.0.2.0/24"
}

# -----------------------------------------------------------------------------
# Virtual Machine Configuration
# -----------------------------------------------------------------------------

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2ms"
}

variable "vm_admin_username" {
  description = "VM admin username"
  type        = string
  default     = "azureuser"
}

variable "vm_ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_allowed_ip" {
  description = "IP address allowed to SSH to the VM (use your public IP or CIDR range)"
  type        = string
  default     = "*"
}

# -----------------------------------------------------------------------------
# Coder Configuration
# -----------------------------------------------------------------------------

variable "coder_version" {
  description = "Coder server version"
  type        = string
  default     = "2.16.1"
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

# -----------------------------------------------------------------------------
# Workspace Configuration
# -----------------------------------------------------------------------------

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
