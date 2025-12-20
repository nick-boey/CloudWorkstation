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

# Build images
cd "$PROJECT_DIR/docker"

echo ""
echo "Building .NET 8.0 image..."
docker build -t "$ACR_SERVER/devcontainer-dotnet:8.0" \
    --build-arg DOTNET_VERSION=8.0 \
    --platform linux/amd64 \
    .

echo ""
echo "Building .NET 9.0 image..."
docker build -t "$ACR_SERVER/devcontainer-dotnet:9.0" \
    --build-arg DOTNET_VERSION=9.0 \
    --platform linux/amd64 \
    .

# Push images
echo ""
echo "Pushing .NET 8.0 image..."
docker push "$ACR_SERVER/devcontainer-dotnet:8.0"

echo ""
echo "Pushing .NET 9.0 image..."
docker push "$ACR_SERVER/devcontainer-dotnet:9.0"

echo ""
echo "=== Build Complete ==="
echo "Images pushed:"
echo "  - $ACR_SERVER/devcontainer-dotnet:8.0"
echo "  - $ACR_SERVER/devcontainer-dotnet:9.0"
