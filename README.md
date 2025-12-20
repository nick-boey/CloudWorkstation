# Cloud Workstation

A Coder-based development environment running on Azure Container Apps, with .NET, Git, GitHub CLI, and Claude Code pre-installed.

## Features

- **Azure Container Apps**: Serverless, auto-scaling container hosting
- **Azure AD Authentication**: Enterprise SSO with your Microsoft account
- **Persistent Storage**: Azure Files for workspace data that survives restarts
- **.NET Development**: Full .NET SDK (8.0 or 9.0)
- **Git Worktrees**: Work on multiple branches simultaneously
- **Claude Code CLI**: AI-powered coding assistant
- **SSH Access**: Connect from any terminal or mobile app

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Docker](https://www.docker.com/get-started) (for building custom images)
- An Azure subscription with permissions to create resources

## Quick Start

### 1. Clone and Configure

```bash
cd CloudWorkstation/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:

```hcl
admin_email = "your-email@example.com"
```

### 2. Deploy Infrastructure

```bash
# Login to Azure
az login

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply
```

### 3. Configure Coder Access URL

After the initial deployment, configure Coder with its access URL:

```bash
# Using PowerShell (Windows)
.\scripts\configure-coder.ps1

# Or using bash (Linux/macOS/WSL)
./scripts/configure-coder.sh
```

This sets the `CODER_ACCESS_URL` environment variable and restarts the Coder server.

### 4. Build and Push Container Image

After Terraform completes, build and push the dev container:

```bash
# Get registry credentials from Terraform output
ACR_SERVER=$(terraform output -raw container_registry_login_server)
ACR_USERNAME=$(terraform output -raw container_registry_username)
ACR_PASSWORD=$(terraform output -raw container_registry_password)

# Login to Azure Container Registry
docker login $ACR_SERVER -u $ACR_USERNAME -p $ACR_PASSWORD

# Build for .NET 8.0
cd ../docker
docker build -t $ACR_SERVER/devcontainer-dotnet:8.0 --build-arg DOTNET_VERSION=8.0 .

# Build for .NET 9.0 (optional)
docker build -t $ACR_SERVER/devcontainer-dotnet:9.0 --build-arg DOTNET_VERSION=9.0 .

# Push images
docker push $ACR_SERVER/devcontainer-dotnet:8.0
docker push $ACR_SERVER/devcontainer-dotnet:9.0
```

### 5. Set Up Coder Workspace Template

1. Get the Coder URL from Terraform output:
   ```bash
   terraform output coder_url
   ```

2. Open the URL in your browser and sign in with your Microsoft account

3. Create the workspace template:
   - Go to **Templates** > **Create Template**
   - Upload the files from the `coder/` directory
   - Configure the template variables with values from Terraform outputs

### 6. Create Your First Workspace

1. In Coder, click **Create Workspace**
2. Select the workspace template
3. Configure:
   - **CPU**: 2/4/8 cores
   - **Memory**: 8/16/32 GB
   - **.NET Version**: 8.0 or 9.0
   - **Git Repositories**: Comma-separated list of repos to clone

4. Click **Create** and wait for the workspace to start

## Connecting to Your Workspace

### SSH Configuration

Coder provides SSH access through its tunnel. First, configure your SSH:

```bash
# Install Coder CLI
# Windows (PowerShell)
winget install Coder.Coder

# macOS
brew install coder/coder/coder

# Linux
curl -fsSL https://coder.com/install.sh | sh
```

Then configure SSH:

```bash
# Login to Coder
coder login https://your-coder-url.azurecontainerapps.io

# Configure SSH
coder config-ssh
```

This adds entries to your `~/.ssh/config` for each workspace.

### Desktop SSH (Terminal/VS Code)

```bash
# Connect via SSH
ssh coder.workspace-name

# Or use the Coder CLI
coder ssh workspace-name
```

For VS Code, install the **Remote - SSH** extension and connect to `coder.workspace-name`.

### Mobile SSH with Termius

#### Initial Setup

1. **Install Termius** from App Store (iOS) or Play Store (Android)

2. **Get SSH Key from Coder**:
   ```bash
   # On your desktop, export the Coder SSH key
   coder config-ssh --dry-run
   # Look for the IdentityFile path, usually ~/.ssh/coder_*
   ```

3. **Transfer the Key to Termius**:
   - Option A: Use Termius Keychain sync (requires Termius Premium)
   - Option B: Copy the private key content and paste in Termius

#### Termius Configuration

1. **Add SSH Key**:
   - Go to **Keychain** > **Keys** > **+**
   - Name: `Coder Key`
   - Import the Coder private key

2. **Add Host**:
   - Go to **Hosts** > **+**
   - **Label**: `My Workspace`
   - **Hostname**: Use the Coder tunnel address (see below)
   - **Username**: `vscode`
   - **Keys**: Select `Coder Key`

#### Getting the Tunnel Address

For mobile access without port forwarding, you have two options:

**Option A: Coder Tunnel (Recommended)**

Coder provides a built-in tunnel. From your workspace terminal:
```bash
# The Coder agent automatically provides SSH access
# Connect via: coder.<workspace-name>.coder
```

**Option B: Use Tailscale/Cloudflare Tunnel**

For a permanent address accessible from mobile:

1. Install Tailscale in your workspace
2. Connect to your Tailscale network
3. Use the Tailscale IP in Termius

## First-Time Workspace Setup

After creating a new workspace, run the credential setup:

```bash
setup-credentials.sh
```

This will configure:
- Git username and email
- GitHub CLI authentication
- SSH key generation (optional)

### GitHub CLI Login

```bash
gh auth login
```

Choose "GitHub.com" > "SSH" > "Login with a web browser"

### Claude Code Setup

```bash
# Option 1: Interactive login
claude login

# Option 2: Set API key directly
claude config set apiKey sk-ant-xxxxx
```

## Working with Git Worktrees

The workspace is set up for efficient multi-branch development using Git worktrees.

### Clone a Repository

```bash
setup-worktree.sh https://github.com/user/repo.git
```

This creates:
- `~/repos/repo.git/` - Bare repository
- `~/repos/repo/main/` - Main branch worktree

### Add Additional Worktrees

```bash
# Work on a feature branch
setup-worktree.sh --add repo feature-branch

# Work on a bugfix
setup-worktree.sh --add repo hotfix-123
```

### List All Worktrees

```bash
setup-worktree.sh --list
```

### Remove a Worktree

```bash
setup-worktree.sh --remove repo feature-branch
```

### Directory Structure

```
~/repos/
├── myrepo.git/           # Bare repository
├── myrepo/
│   ├── main/             # Main branch
│   ├── feature-auth/     # Feature branch
│   └── bugfix-123/       # Bugfix branch
├── another-repo.git/
└── another-repo/
    └── main/
```

## Running Multiple Agents

With worktrees, you can run multiple Claude Code agents simultaneously:

```bash
# Terminal 1 - Working on feature
cd ~/repos/myrepo/feature-auth
claude

# Terminal 2 - Working on bugfix
cd ~/repos/myrepo/bugfix-123
claude

# Terminal 3 - Main branch maintenance
cd ~/repos/myrepo/main
claude
```

Each agent works in its own isolated branch directory.

## Persistence

The following data persists across workspace restarts:

| Data | Location | Backed by |
|------|----------|-----------|
| Home directory | `/home/vscode` | Azure Files |
| Git config | `~/.gitconfig` | Azure Files |
| GitHub CLI | `~/.config/gh/` | Azure Files |
| Claude Code | `~/.claude/` | Azure Files |
| SSH keys | `~/.ssh/` | Azure Files |
| Repositories | `~/repos/` | Azure Files |

## Troubleshooting

### Workspace Won't Start

Check the Container App logs in Azure Portal:
1. Go to your resource group
2. Find the Container App for your workspace
3. Check **Log stream** or **Console logs**

### SSH Connection Refused

1. Verify the workspace is running in Coder UI
2. Re-run `coder config-ssh` to refresh SSH config
3. Check if the Coder agent is running in the workspace

### Slow Performance

Consider upgrading your workspace resources:
1. Stop the workspace
2. Edit parameters (CPU/Memory)
3. Start the workspace

### Lost Credentials

Credentials are stored in Azure Files. If they're missing:
1. Check if the storage account exists
2. Verify the file share is mounted
3. Re-run `setup-credentials.sh`

## Costs

Estimated monthly costs (Australia East region):

| Resource | SKU | Est. Cost (AUD) |
|----------|-----|-----------------|
| Container App Environment | Consumption | ~$20/month base |
| Container App (Coder Server) | 1 vCPU, 2GB | ~$40/month |
| Container App (Workspace) | 2 vCPU, 8GB | ~$80/month (when running) |
| Azure Files | 50GB | ~$10/month |
| Container Registry | Basic | ~$7/month |

**Total**: ~$150-200/month with one active workspace

*Container Apps charges only for running time. Stop workspaces when not in use to reduce costs.*

## Clean Up

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## License

MIT License
