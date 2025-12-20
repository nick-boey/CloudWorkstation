# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# -----------------------------------------------------------------------------
# Random Suffix for Unique Names
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -----------------------------------------------------------------------------
# Azure Container Registry
# -----------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  name                = "acrcoderws${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Storage Account for Persistent Data
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "main" {
  name                     = "stcoderws${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_share" "coder_data" {
  name                 = "coder-data"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 50
}

resource "azurerm_storage_share" "workspace_data" {
  name                 = "workspace-data"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 100
}

# -----------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-coder-ws-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Container App Environment
# -----------------------------------------------------------------------------

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-coder-ws-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = var.tags
}

resource "azurerm_container_app_environment_storage" "coder_data" {
  name                         = "coder-data"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  share_name                   = azurerm_storage_share.coder_data.name
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app_environment_storage" "workspace_data" {
  name                         = "workspace-data"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  share_name                   = azurerm_storage_share.workspace_data.name
  access_mode                  = "ReadWrite"
}

# -----------------------------------------------------------------------------
# Azure AD Application for Coder OIDC
# -----------------------------------------------------------------------------

resource "azuread_application" "coder" {
  display_name = "Coder Workstation"
  owners       = [data.azuread_client_config.current.object_id]

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
    resource_access {
      id   = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0" # email
      type = "Scope"
    }
    resource_access {
      id   = "14dad69e-099b-42c9-810b-d002981feec1" # profile
      type = "Scope"
    }
  }

  optional_claims {
    id_token {
      name = "email"
    }
  }
}

resource "azuread_application_password" "coder" {
  application_id = azuread_application.coder.id
  display_name   = "Coder OIDC Secret"
  end_date       = timeadd(timestamp(), "8760h") # 1 year
}

resource "azuread_service_principal" "coder" {
  client_id = azuread_application.coder.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# -----------------------------------------------------------------------------
# Coder Server Container App
# -----------------------------------------------------------------------------

resource "azurerm_container_app" "coder" {
  name                         = "ca-coder-server"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"
  tags                         = var.tags

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "coder"
      image  = "ghcr.io/coder/coder:v${var.coder_version}"
      cpu    = 1
      memory = "2Gi"

      env {
        name  = "CODER_HTTP_ADDRESS"
        value = "0.0.0.0:7080"
      }

      env {
        name  = "CODER_OIDC_ISSUER_URL"
        value = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
      }

      env {
        name  = "CODER_OIDC_CLIENT_ID"
        value = azuread_application.coder.client_id
      }

      env {
        name        = "CODER_OIDC_CLIENT_SECRET"
        secret_name = "oidc-client-secret"
      }

      env {
        name  = "CODER_OIDC_EMAIL_DOMAIN"
        value = ""
      }

      env {
        name  = "CODER_OIDC_SCOPES"
        value = "openid,profile,email"
      }

      env {
        name  = "CODER_TELEMETRY_ENABLE"
        value = "false"
      }

      volume_mounts {
        name = "coder-data"
        path = "/coder-data"
      }
    }

    volume {
      name         = "coder-data"
      storage_name = azurerm_container_app_environment_storage.coder_data.name
      storage_type = "AzureFile"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 7080
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  secret {
    name  = "oidc-client-secret"
    value = azuread_application_password.coder.value
  }

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].env,
    ]
  }
}

# -----------------------------------------------------------------------------
# Update Azure AD Application with Correct Redirect URI
# -----------------------------------------------------------------------------

resource "azuread_application_redirect_uris" "coder" {
  application_id = azuread_application.coder.id
  type           = "Web"

  redirect_uris = [
    "https://${azurerm_container_app.coder.ingress[0].fqdn}/api/v2/users/oidc/callback"
  ]
}
