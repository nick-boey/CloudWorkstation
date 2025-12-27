terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "coder" {}

# -----------------------------------------------------------------------------
# Coder Template Variables (from Terraform outputs)
# -----------------------------------------------------------------------------

variable "aci_subnet_id" {
  description = "Azure Container Instance subnet ID"
  type        = string
}

variable "container_registry_server" {
  description = "Container registry login server"
  type        = string
}

variable "container_registry_username" {
  description = "Container registry username"
  type        = string
}

variable "container_registry_password" {
  description = "Container registry password"
  type        = string
  sensitive   = true
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "storage_account_key" {
  description = "Storage account key"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "vm_private_ip" {
  description = "VM private IP address (for Coder and Happy Server)"
  type        = string
}

variable "coder_access_url" {
  description = "Coder server access URL"
  type        = string
}

# -----------------------------------------------------------------------------
# Coder Data Sources
# -----------------------------------------------------------------------------

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# -----------------------------------------------------------------------------
# Workspace Parameters
# -----------------------------------------------------------------------------

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for the workspace"
  type         = "number"
  default      = "2"
  mutable      = true

  option {
    name  = "2 cores"
    value = "2"
  }
  option {
    name  = "4 cores"
    value = "4"
  }
  option {
    name  = "8 cores"
    value = "8"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of RAM for the workspace"
  type         = "number"
  default      = "8"
  mutable      = true

  option {
    name  = "8 GB"
    value = "8"
  }
  option {
    name  = "16 GB"
    value = "16"
  }
  option {
    name  = "32 GB"
    value = "32"
  }
}

data "coder_parameter" "dotnet_version" {
  name         = "dotnet_version"
  display_name = ".NET Version"
  description  = "Version of .NET SDK"
  type         = "string"
  default      = "9.0"
  mutable      = false

  option {
    name  = ".NET 8.0 (LTS)"
    value = "8.0"
  }
  option {
    name  = ".NET 9.0"
    value = "9.0"
  }
}

data "coder_parameter" "git_repository" {
  name         = "git_repository"
  display_name = "Git Repository"
  description  = "Git repository URL to clone on startup (will run Happy CLI in this directory)"
  type         = "string"
  default      = ""
  mutable      = true
}

# -----------------------------------------------------------------------------
# Coder Agent
# -----------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  display_apps {
    vscode                 = false
    vscode_insiders        = false
    ssh_helper             = true
    port_forwarding_helper = true
    web_terminal           = true
  }

  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Ensure directories exist with correct permissions
    mkdir -p ~/.ssh ~/.config/gh ~/.claude ~/.happy ~/.dotnet ~/repos
    chmod 700 ~/.ssh

    # Clone repository if specified
    REPO="${data.coder_parameter.git_repository.value}"
    if [ -n "$REPO" ]; then
      REPO_NAME=$(basename "$REPO" .git)
      REPO_DIR="/home/vscode/repos/$REPO_NAME"

      if [ ! -d "$REPO_DIR" ]; then
        echo "Cloning $REPO..."
        git clone "$REPO" "$REPO_DIR"
      else
        echo "Repository $REPO_NAME already exists, pulling latest..."
        cd "$REPO_DIR" && git pull || true
      fi

      cd "$REPO_DIR"
      echo "Starting Happy CLI in $REPO_DIR..."

      # Start Happy CLI (connects Claude Code to mobile)
      if command -v happy &> /dev/null; then
        happy &
        HAPPY_PID=$!
        echo "Happy CLI started with PID $HAPPY_PID"
      else
        echo "Happy CLI not found, skipping..."
      fi
    fi

    echo "Workspace ready!"
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "cpu_usage"
    script       = "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"
    interval     = 10
    timeout      = 5
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem_usage"
    script       = "free -m | awk 'NR==2{printf \"%.1f%%\", $3*100/$2}'"
    interval     = 10
    timeout      = 5
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk_usage"
    script       = "df -h /home/vscode | awk 'NR==2{print $5}'"
    interval     = 60
    timeout      = 5
  }
}

# -----------------------------------------------------------------------------
# Azure Container Instance for Workspace
# -----------------------------------------------------------------------------

resource "azurerm_container_group" "workspace" {
  name                = "aci-ws-${lower(replace(data.coder_workspace.me.name, "/[^a-z0-9-]/", "-"))}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  ip_address_type     = "Private"
  subnet_ids          = [var.aci_subnet_id]
  restart_policy      = data.coder_workspace.me.start_count > 0 ? "Always" : "Never"

  image_registry_credential {
    server   = var.container_registry_server
    username = var.container_registry_username
    password = var.container_registry_password
  }

  container {
    name   = "workspace"
    image  = "${var.container_registry_server}/devcontainer-dotnet:${data.coder_parameter.dotnet_version.value}"
    cpu    = data.coder_parameter.cpu.value
    memory = data.coder_parameter.memory.value

    environment_variables = {
      CODER_AGENT_URL   = var.coder_access_url
      HAPPY_SERVER_URL  = "http://${var.vm_private_ip}:3005"
      GIT_REPOSITORY    = data.coder_parameter.git_repository.value
    }

    secure_environment_variables = {
      CODER_AGENT_TOKEN = coder_agent.main.token
    }

    volume {
      name                 = "workspace-data"
      mount_path           = "/home/vscode"
      storage_account_name = var.storage_account_name
      storage_account_key  = var.storage_account_key
      share_name           = "workspace-data"
    }

    ports {
      port     = 22
      protocol = "TCP"
    }
  }

  tags = {
    Workspace = data.coder_workspace.me.name
    Owner     = data.coder_workspace_owner.me.name
    ManagedBy = "Coder"
  }

  lifecycle {
    ignore_changes = [
      container[0].secure_environment_variables,
    ]
  }
}

# -----------------------------------------------------------------------------
# Workspace Metadata
# -----------------------------------------------------------------------------

resource "coder_metadata" "workspace" {
  count       = 1
  resource_id = azurerm_container_group.workspace.id

  item {
    key   = "CPU"
    value = "${data.coder_parameter.cpu.value} cores"
  }
  item {
    key   = "Memory"
    value = "${data.coder_parameter.memory.value} GB"
  }
  item {
    key   = ".NET Version"
    value = data.coder_parameter.dotnet_version.value
  }
  item {
    key   = "Repository"
    value = data.coder_parameter.git_repository.value != "" ? data.coder_parameter.git_repository.value : "None"
  }
}
