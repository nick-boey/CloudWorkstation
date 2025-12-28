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

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
}

provider "coder" {}

# -----------------------------------------------------------------------------
# Coder Template Variables
# -----------------------------------------------------------------------------

variable "container_app_environment_id" {
  description = "Azure Container App Environment ID"
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
  display_name = "Memory"
  description  = "Amount of RAM for the workspace"
  type         = "string"
  default      = "8Gi"
  mutable      = true

  option {
    name  = "8 GB"
    value = "8Gi"
  }
  option {
    name  = "16 GB"
    value = "16Gi"
  }
  option {
    name  = "32 GB"
    value = "32Gi"
  }
}

data "coder_parameter" "dotnet_version" {
  name         = "dotnet_version"
  display_name = ".NET Version"
  description  = "Version of .NET SDK"
  type         = "string"
  default      = "8.0"
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

data "coder_parameter" "git_repos" {
  name         = "git_repos"
  display_name = "Git Repositories"
  description  = "Comma-separated list of Git repository URLs to clone (e.g., https://github.com/user/repo1,https://github.com/user/repo2)"
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
    vscode          = false
    vscode_insiders = false
    ssh_helper      = true
    port_forwarding_helper = true
    web_terminal    = true
  }

  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Ensure SSH directory exists with correct permissions
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # Setup git worktrees for each repository
    REPOS="${data.coder_parameter.git_repos.value}"
    if [ -n "$REPOS" ]; then
      IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
      for repo in "$${REPO_ARRAY[@]}"; do
        repo=$(echo "$repo" | xargs)  # Trim whitespace
        if [ -n "$repo" ]; then
          repo_name=$(basename "$repo" .git)

          if [ ! -d "/home/vscode/repos/$repo_name" ]; then
            echo "Cloning $repo..."
            git clone --bare "$repo" "/home/vscode/repos/$repo_name.git"

            # Create main worktree
            cd "/home/vscode/repos/$repo_name.git"
            git worktree add "/home/vscode/repos/$repo_name/main" HEAD

            echo "Repository $repo_name set up with worktrees"
          fi
        fi
      done
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
# Azure Container App for Workspace
# -----------------------------------------------------------------------------

resource "azurerm_container_app" "workspace" {
  name                         = "ws-${lower(data.coder_workspace.me.name)}"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"

  template {
    min_replicas = data.coder_workspace.me.start_count
    max_replicas = data.coder_workspace.me.start_count

    container {
      name   = "workspace"
      image  = "${var.container_registry_server}/devcontainer-dotnet:${data.coder_parameter.dotnet_version.value}"
      cpu    = data.coder_parameter.cpu.value
      memory = data.coder_parameter.memory.value

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      env {
        name  = "CODER_AGENT_URL"
        value = data.coder_workspace.me.access_url
      }

      volume_mounts {
        name = "workspace-data"
        path = "/home/vscode"
      }
    }

    volume {
      name         = "workspace-data"
      storage_name = "workspace-data"
      storage_type = "AzureFile"
    }
  }

  registry {
    server               = var.container_registry_server
    username             = var.container_registry_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = var.container_registry_password
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

resource "coder_metadata" "workspace" {
  count       = 1
  resource_id = azurerm_container_app.workspace.id

  item {
    key   = "CPU"
    value = "${data.coder_parameter.cpu.value} cores"
  }
  item {
    key   = "Memory"
    value = data.coder_parameter.memory.value
  }
  item {
    key   = ".NET Version"
    value = data.coder_parameter.dotnet_version.value
  }
}
