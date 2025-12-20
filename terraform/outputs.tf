output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "coder_url" {
  description = "URL to access Coder"
  value       = "https://${azurerm_container_app.coder.ingress[0].fqdn}"
}

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

output "azure_ad_tenant_id" {
  description = "Azure AD tenant ID for OIDC"
  value       = data.azurerm_client_config.current.tenant_id
}

output "azure_ad_client_id" {
  description = "Azure AD application client ID"
  value       = azuread_application.coder.client_id
}

output "storage_account_name" {
  description = "Storage account name for persistent data"
  value       = azurerm_storage_account.main.name
}

output "storage_account_key" {
  description = "Storage account access key"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "container_app_environment_id" {
  description = "Container App Environment ID for Coder templates"
  value       = azurerm_container_app_environment.main.id
}
