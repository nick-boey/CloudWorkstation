#!/bin/bash
# build-and-push.sh - Build and push the dev container image to ACR
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Get Terraform outputs
cd "$PROJECT_DIR/terraform"

echo "Getting Terraform outputs..."
ACR_SERVER=$(terraform output -raw container_registry_login_server 2>/dev/null)
ACR_USERNAME=$(terraform output -raw container_registry_username 2>/dev/null)
ACR_PASSWORD=$(terraform output -raw container_registry_password 2>/dev/null)

if [ -z "$ACR_SERVER" ]; then
    echo "Error: Could not get ACR credentials from Terraform."
    echo "Make sure you have run 'terraform apply' first."
    exit 1
fi

echo "ACR Server: $ACR_SERVER"

# Login to ACR
echo "Logging into Azure Container Registry..."
echo "$ACR_PASSWORD" | docker login "$ACR_SERVER" -u "$ACR_USERNAME" --password-stdin

# Build image
cd "$PROJECT_DIR/docker"

echo ""
echo "Building devcontainer image..."
docker build -t "$ACR_SERVER/devcontainer-dotnet:latest" \
    --platform linux/amd64 \
    .

# Push image
echo ""
echo "Pushing devcontainer image..."
docker push "$ACR_SERVER/devcontainer-dotnet:latest"

echo ""
echo "=== Build Complete ==="
echo "Image pushed:"
echo "  - $ACR_SERVER/devcontainer-dotnet:latest"
echo ""
echo "This image includes:"
echo "  - .NET SDK (latest)"
echo "  - Claude Code CLI"
echo "  - Happy CLI (for mobile Claude Code connectivity)"
echo "  - GitHub CLI"
