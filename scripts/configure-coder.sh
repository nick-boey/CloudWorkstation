#!/bin/bash
# configure-coder.sh - Configure Coder environment variables after initial deployment
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Get Terraform outputs
cd "$PROJECT_DIR/terraform"

echo "Getting deployment details..."
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
CODER_URL=$(terraform output -raw coder_url)

if [ -z "$RESOURCE_GROUP" ]; then
    echo "Error: Could not get resource group from Terraform."
    echo "Make sure you have run 'terraform apply' first."
    exit 1
fi

echo "Resource Group: $RESOURCE_GROUP"
echo "Coder URL: $CODER_URL"

# Update Container App environment variable
echo ""
echo "Updating Coder Container App with CODER_ACCESS_URL..."
az containerapp update \
    --name ca-coder-server \
    --resource-group "$RESOURCE_GROUP" \
    --set-env-vars "CODER_ACCESS_URL=$CODER_URL" \
    --output none

echo ""
echo "=== Configuration Complete ==="
echo "Coder is now accessible at: $CODER_URL"
echo ""
echo "The Container App will restart automatically with the new configuration."
echo "Wait a minute or two, then visit the URL to complete setup."
