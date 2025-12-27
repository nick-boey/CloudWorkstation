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

output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.main.id
}

output "vm_subnet_id" {
  description = "VM subnet ID"
  value       = azurerm_subnet.vm.id
}

output "aci_subnet_id" {
  description = "ACI subnet ID"
  value       = azurerm_subnet.aci.id
}

output "vm_private_ip" {
  description = "VM private IP address"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "vm_public_ip" {
  description = "VM public IP address"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_fqdn" {
  description = "VM fully qualified domain name"
  value       = azurerm_public_ip.vm.fqdn
}

# -----------------------------------------------------------------------------
# URLs
# -----------------------------------------------------------------------------

output "coder_url" {
  description = "URL to access Coder"
  value       = "https://${azurerm_public_ip.vm.fqdn}"
}

output "happy_server_url" {
  description = "URL for Happy Server (internal use by containers)"
  value       = "http://${azurerm_network_interface.vm.private_ip_address}:3005"
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

output "container_registry_login_server" {
  description = "Container registry login server"
  value       = azurerm_container_registry.main.login_server
}

output "container_registry_username" {
  description = "Container registry admin username"
  value       = azurerm_container_registry.main.admin_username
}

output "container_registry_password" {
  description = "Container registry admin password"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Azure AD
# -----------------------------------------------------------------------------

output "azure_ad_tenant_id" {
  description = "Azure AD tenant ID for OIDC"
  value       = data.azurerm_client_config.current.tenant_id
}

output "azure_ad_client_id" {
  description = "Azure AD application client ID"
  value       = azuread_application.coder.client_id
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

output "storage_account_name" {
  description = "Storage account name for persistent data"
  value       = azurerm_storage_account.main.name
}

output "storage_account_key" {
  description = "Storage account access key"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

# -----------------------------------------------------------------------------
# SSH Access
# -----------------------------------------------------------------------------

output "ssh_command" {
  description = "SSH command to connect to VM"
  value       = "ssh ${var.vm_admin_username}@${azurerm_public_ip.vm.ip_address}"
}
