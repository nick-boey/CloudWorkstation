# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-dev-workstation"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "australiaeast"
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

variable "vm_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 64
}

variable "ssh_allowed_ip" {
  description = "IP address allowed to SSH to the VM (use your public IP or CIDR range)"
  type        = string
  default     = "*"
}
