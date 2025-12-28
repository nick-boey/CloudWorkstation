# Cloud Workstation (VM-Only Setup)

A simple Azure VM-based development environment with .NET 9, GitHub CLI, and Happy CLI for mobile Claude Code connectivity.

## Architecture

```
┌────────────────────────────────────────────┐
│              Azure Virtual Network          │
│                                            │
│  ┌────────────────────────────────────┐    │
│  │        Ubuntu 24.04 LTS VM         │    │
│  │                                    │    │
│  │  - .NET 9 SDK                      │    │
│  │  - GitHub CLI                      │    │
│  │  - Happy CLI (cloud relay)         │    │
│  │  - Node.js 20 LTS                  │    │
│  │                                    │    │
│  └────────────────────────────────────┘    │
│                                            │
└────────────────────────────────────────────┘
```

## Features

- **Simple VM**: Ubuntu 24.04 LTS with development tools pre-installed
- **.NET 9 SDK**: Latest .NET for cross-platform development
- **GitHub CLI**: Repository management via `gh` command
- **Happy CLI**: Mobile Claude Code connectivity via cloud relay (no self-hosted server)
- **SSH Access**: Simple SSH key authentication

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- An Azure subscription with permissions to create resources
- An SSH key pair for VM access

### Generating an SSH Key

If you don't have an SSH key, generate one:

```bash
# Generate a new Ed25519 SSH key (recommended)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Or RSA if Ed25519 isn't supported
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

Copy your **public** key for use in `terraform.tfvars`:

```bash
# Windows (PowerShell)
Get-Content ~/.ssh/id_ed25519.pub

# macOS/Linux
cat ~/.ssh/id_ed25519.pub
```

## Quick Start

### 1. Clone and Configure

```bash
cd CloudWorkstation/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
vm_ssh_public_key = "ssh-ed25519 AAAA... your-key"

# Optional: Restrict SSH access to your IP
ssh_allowed_ip = "YOUR_PUBLIC_IP/32"
```

### 2. Deploy Infrastructure

```bash
# Login to Azure
az login

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (takes ~5 minutes)
terraform apply
```

### 3. Connect to Your VM

```bash
# Get SSH command from Terraform output
terraform output ssh_command

# Example output: ssh azureuser@<public-ip>
```

### 4. First-Time Setup

After connecting via SSH, configure your development environment:

```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"

# Login to GitHub CLI
gh auth login

# Verify .NET installation
dotnet --version
```

## Using Happy CLI

Happy CLI connects to the cloud-hosted Happy relay server, allowing you to control Claude Code from your mobile device.

```bash
# Navigate to your project
cd ~/repos/your-project

# Start Happy CLI
happy

# Scan the displayed QR code with your mobile device
```

To connect from your phone:
1. Install the [Happy mobile app](https://happy.engineering/)
2. Scan the QR code shown in the terminal
3. Control Claude Code from your mobile device

## Installed Tools

| Tool | Version | Purpose |
|------|---------|---------|
| .NET SDK | 9.0 | .NET development |
| Node.js | 20 LTS | JavaScript runtime |
| GitHub CLI | Latest | Repository management |
| Happy CLI | Latest | Mobile Claude Code |
| Git | Latest | Version control |
| tmux | Latest | Terminal multiplexer |

## Costs

Estimated monthly costs (Australia East region):

| Resource | SKU | Est. Cost (AUD) |
|----------|-----|-----------------|
| Azure VM | Standard_B2ms | ~$60/month |
| Managed Disk | 64GB Premium SSD | ~$10/month |
| Public IP | Static | ~$3/month |

**Total**: ~$73/month

*Stop the VM when not in use to reduce costs.*

## Clean Up

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## Project Structure

```
CloudWorkstation/
├── terraform/
│   ├── main.tf           # VM, VNet, networking
│   ├── variables.tf      # Configuration variables
│   ├── outputs.tf        # Output values
│   ├── providers.tf      # Provider configuration
│   └── cloud-init.yaml   # VM bootstrap script
└── README.md
```

## Troubleshooting

### Cloud-init Not Complete

Check if cloud-init has finished:

```bash
# Check if complete
ls /var/log/cloud-init-complete

# View cloud-init logs
sudo cat /var/log/cloud-init-output.log
```

### .NET Not Found

If `dotnet` command is not found after initial login:

```bash
# Source the profile
source /etc/profile.d/dotnet.sh

# Or logout and login again
exit
# Then reconnect
```

### Happy CLI Not Working

```bash
# Verify installation
which happy

# Check Node.js
node --version

# Reinstall if needed
sudo npm install -g happy-coder
```

## License

MIT License
