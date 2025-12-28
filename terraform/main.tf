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

resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "random_password" "happy_seed" {
  length  = 64
  special = false
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
# Virtual Network
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "vnet-coder-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "vm" {
  name                 = "snet-vm"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.vm_subnet_prefix]
}

resource "azurerm_subnet" "aci" {
  name                 = "snet-aci"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aci_subnet_prefix]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# -----------------------------------------------------------------------------
# Network Security Group
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "vm" {
  name                = "nsg-vm-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_allowed_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHappyServerFromVNet"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3005"
    source_address_prefix      = var.vnet_address_space
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowCoderFromVNet"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7080"
    source_address_prefix      = var.vnet_address_space
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# -----------------------------------------------------------------------------
# Public IP Address
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "vm" {
  name                = "pip-coder-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "coder-${random_string.suffix.result}"
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Network Interface
# -----------------------------------------------------------------------------

resource "azurerm_network_interface" "vm" {
  name                = "nic-coder-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.vm_subnet_prefix, 4)
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
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

  web {
    redirect_uris = [
      "https://${azurerm_public_ip.vm.fqdn}/api/v2/users/oidc/callback"
    ]
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
# Virtual Machine
# -----------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-coder-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    storage_account_name    = azurerm_storage_account.main.name
    storage_account_key     = azurerm_storage_account.main.primary_access_key
    coder_data_share        = azurerm_storage_share.coder_data.name
    workspace_data_share    = azurerm_storage_share.workspace_data.name
    postgres_password       = random_password.postgres.result
    happy_seed              = random_password.happy_seed.result
    coder_version           = var.coder_version
    oidc_issuer_url         = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
    oidc_client_id          = azuread_application.coder.client_id
    oidc_client_secret      = azuread_application_password.coder.value
    vm_fqdn                 = azurerm_public_ip.vm.fqdn
    vm_private_ip           = cidrhost(var.vm_subnet_prefix, 4)
    acr_login_server        = azurerm_container_registry.main.login_server
    acr_username            = azurerm_container_registry.main.admin_username
    acr_password            = azurerm_container_registry.main.admin_password
  }))
}

# Grant VM access to ACR
resource "azurerm_role_assignment" "vm_acr" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine.main.identity[0].principal_id
}
