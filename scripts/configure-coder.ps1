# configure-coder.ps1 - Configure Coder environment variables after initial deployment
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

# Get Terraform outputs
Push-Location "$ProjectDir\terraform"

Write-Host "Getting deployment details..."
$RESOURCE_GROUP = terraform output -raw resource_group_name
$CODER_URL = terraform output -raw coder_url

if (-not $RESOURCE_GROUP) {
    Write-Error "Could not get resource group from Terraform. Make sure you have run 'terraform apply' first."
    exit 1
}

Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "Coder URL: $CODER_URL"

# Update Container App environment variable
Write-Host ""
Write-Host "Updating Coder Container App with CODER_ACCESS_URL..."
az containerapp update `
    --name ca-coder-server `
    --resource-group $RESOURCE_GROUP `
    --set-env-vars "CODER_ACCESS_URL=$CODER_URL" `
    --output none

Pop-Location

Write-Host ""
Write-Host "=== Configuration Complete ==="
Write-Host "Coder is now accessible at: $CODER_URL"
Write-Host ""
Write-Host "The Container App will restart automatically with the new configuration."
Write-Host "Wait a minute or two, then visit the URL to complete setup."
