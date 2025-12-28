# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

output "vm_public_ip" {
  description = "VM public IP address"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_fqdn" {
  description = "VM fully qualified domain name"
  value       = azurerm_public_ip.vm.fqdn
}

# -----------------------------------------------------------------------------
# SSH Access
# -----------------------------------------------------------------------------

output "ssh_command" {
  description = "SSH command to connect to VM"
  value       = "ssh ${var.vm_admin_username}@${azurerm_public_ip.vm.ip_address}"
}
