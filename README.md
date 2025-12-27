# Cloud Workstation

A Coder-based development environment running on Azure with Happy Server integration for mobile Claude Code connectivity.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Azure Virtual Network                        │
│                                                                       │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────┐│
│  │     VM (Coder + Happy Server)   │  │   Dev Containers (ACI)      ││
│  │                                 │  │                             ││
│  │  - Coder Server                 │  │  - .NET SDK                 ││
│  │  - Happy Server (relay)         │  │  - Claude Code CLI          ││
│  │  - PostgreSQL                   │  │  - Happy CLI                ││
│  │  - Redis                        │  │  - GitHub CLI               ││
│  │  - Caddy (HTTPS)                │  │                             ││
│  └─────────────────────────────────┘  └─────────────────────────────┘│
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

- **Azure VM**: Hosts Coder server and Happy Server relay
- **Azure Container Instances**: Scalable development containers with VNet integration
- **Happy Server**: Self-hosted relay for mobile Claude Code connectivity
- **Azure AD Authentication**: Enterprise SSO with your Microsoft account
- **Persistent Storage**: Azure Files for credentials and workspace data
- **.NET Development**: Full .NET SDK (8.0 or 9.0)
- **Claude Code + Happy CLI**: AI-powered coding with mobile access
- **GitHub CLI**: Pre-installed for repository management

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Docker](https://www.docker.com/get-started) (for building images)
- An Azure subscription with permissions to create resources
- An SSH key pair for VM access

## Quick Start

### 1. Clone and Configure

```bash
cd CloudWorkstation/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
admin_email       = "your-email@example.com"
vm_ssh_public_key = "ssh-rsa AAAA... your-key"

# Optional: Restrict SSH access to your IP
ssh_allowed_ip    = "YOUR_PUBLIC_IP/32"
```

### 2. Deploy Infrastructure

```bash
# Login to Azure
az login

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (takes ~10 minutes)
terraform apply
```

### 3. Build and Push Container Images

After Terraform completes, build the development container:

```bash
./scripts/build-and-push.sh
```

### 4. Access Coder

Get the Coder URL from Terraform output:

```bash
terraform output coder_url
```

Open the URL in your browser and sign in with your Microsoft account.

### 5. Create Coder Template

1. In Coder, go to **Templates** > **Create Template**
2. Upload the files from the `coder/` directory
3. Configure the template variables with values from Terraform outputs:

   ```bash
   # Get all the values you need
   terraform output aci_subnet_id
   terraform output container_registry_login_server
   terraform output container_registry_username
   terraform output -raw container_registry_password
   terraform output storage_account_name
   terraform output -raw storage_account_key
   terraform output resource_group_name
   terraform output vm_private_ip
   terraform output coder_url
   ```

### 6. Create Your First Workspace

1. In Coder, click **Create Workspace**
2. Select your template
3. Configure:
   - **CPU**: 2/4/8 cores
   - **Memory**: 8/16/32 GB
   - **.NET Version**: 8.0 or 9.0
   - **Git Repository**: URL of repo to clone (optional)

4. Click **Create** and wait for the workspace to start

## Mobile Claude Code Access

When you provide a Git repository URL, the workspace automatically:
1. Clones the repository
2. Starts Happy CLI in that directory
3. Displays a QR code for mobile connection

To connect from your phone:
1. Install the [Happy mobile app](https://happy.engineering/)
2. Scan the QR code shown in the workspace terminal
3. Control Claude Code from your mobile device

## SSH Access

### Install Coder CLI

```bash
# Windows (PowerShell)
winget install Coder.Coder

# macOS
brew install coder/coder/coder

# Linux
curl -fsSL https://coder.com/install.sh | sh
```

### Configure SSH

```bash
# Login to Coder
coder login https://your-coder-url.australiaeast.cloudapp.azure.com

# Configure SSH
coder config-ssh

# Connect to workspace
ssh coder.workspace-name
```

### VM SSH Access

For debugging the VM directly:

```bash
# Get SSH command from Terraform
terraform output ssh_command

# Example: ssh azureuser@<public-ip>
```

## First-Time Workspace Setup

After creating a new workspace, configure your credentials:

```bash
setup-credentials.sh
```

This configures:
- Git username and email
- GitHub CLI authentication (`gh auth login`)
- SSH key generation (optional)

### Claude Code Setup

```bash
# Interactive login
claude login

# Or set API key directly
claude config set apiKey sk-ant-xxxxx
```

## Persistence

The following data persists across workspace restarts via Azure Files:

| Data | Location |
|------|----------|
| Git config | `~/.gitconfig` |
| GitHub CLI | `~/.config/gh/` |
| Claude Code | `~/.claude/` |
| Happy CLI | `~/.happy/` |
| SSH keys | `~/.ssh/` |
| Repositories | `~/repos/` |

## Troubleshooting

### VM Services Not Starting

SSH into the VM and check Docker:

```bash
ssh azureuser@<vm-ip>
cd /opt/coder
docker compose ps
docker compose logs
```

### Workspace Won't Start

1. Check the Azure Portal for Container Instance logs
2. Verify the container image was pushed to ACR
3. Check VNet connectivity

### Happy CLI Not Connecting

1. Verify `HAPPY_SERVER_URL` environment variable is set
2. Check Happy Server is running on the VM: `docker compose ps happy-server`
3. Ensure VNet allows traffic on port 3005

### Lost Credentials

Credentials are stored in Azure Files. If they're missing:
1. Check if the storage account exists
2. Verify the file share is mounted
3. Re-run `setup-credentials.sh`

## Costs

Estimated monthly costs (Australia East region):

| Resource | SKU | Est. Cost (AUD) |
|----------|-----|-----------------|
| Azure VM | Standard_B2ms | ~$60/month |
| Managed Disk | 64GB Premium SSD | ~$10/month |
| Public IP | Static | ~$3/month |
| Azure Files | 150GB Standard | ~$8/month |
| Container Registry | Basic | ~$5/month |
| Container Instance | 2 vCPU, 8GB | ~$80/month (when running) |

**Total**: ~$166/month with one active workspace

*ACI charges only for running time. Stop workspaces when not in use to reduce costs.*

## Clean Up

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## Project Structure

```
CloudWorkstation/
├── terraform/              # Azure infrastructure
│   ├── main.tf             # VM, VNet, storage, ACR
│   ├── variables.tf        # Configuration variables
│   ├── outputs.tf          # Output values
│   ├── providers.tf        # Provider configuration
│   └── cloud-init.yaml     # VM bootstrap script
├── coder/                  # Coder workspace template
│   └── main.tf             # ACI-based workspace definition
├── docker/                 # Development container
│   ├── Dockerfile          # .NET + Claude Code + Happy CLI
│   └── scripts/
│       ├── entrypoint.sh   # Container startup
│       ├── setup-credentials.sh
│       └── setup-worktree.sh
├── scripts/
│   └── build-and-push.sh   # Build and push container images
└── README.md
```

## License

MIT License
