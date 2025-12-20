# build-and-push.ps1 - Build and push the dev container image to ACR
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

# Get Terraform outputs
Push-Location "$ProjectDir\terraform"

Write-Host "Getting Terraform outputs..."
$ACR_SERVER = terraform output -raw container_registry_login_server 2>$null
$ACR_USERNAME = terraform output -raw container_registry_username 2>$null
$ACR_PASSWORD = terraform output -raw container_registry_password 2>$null

if (-not $ACR_SERVER) {
    Write-Error "Could not get ACR credentials from Terraform. Make sure you have run 'terraform apply' first."
    exit 1
}

Write-Host "ACR Server: $ACR_SERVER"

# Login to ACR
Write-Host "Logging into Azure Container Registry..."
$ACR_PASSWORD | docker login $ACR_SERVER -u $ACR_USERNAME --password-stdin

# Build images
Set-Location "$ProjectDir\docker"

Write-Host ""
Write-Host "Building .NET 8.0 image..."
docker build -t "$ACR_SERVER/devcontainer-dotnet:8.0" `
    --build-arg DOTNET_VERSION=8.0 `
    --platform linux/amd64 `
    .

Write-Host ""
Write-Host "Building .NET 9.0 image..."
docker build -t "$ACR_SERVER/devcontainer-dotnet:9.0" `
    --build-arg DOTNET_VERSION=9.0 `
    --platform linux/amd64 `
    .

# Push images
Write-Host ""
Write-Host "Pushing .NET 8.0 image..."
docker push "$ACR_SERVER/devcontainer-dotnet:8.0"

Write-Host ""
Write-Host "Pushing .NET 9.0 image..."
docker push "$ACR_SERVER/devcontainer-dotnet:9.0"

Pop-Location

Write-Host ""
Write-Host "=== Build Complete ==="
Write-Host "Images pushed:"
Write-Host "  - $ACR_SERVER/devcontainer-dotnet:8.0"
Write-Host "  - $ACR_SERVER/devcontainer-dotnet:9.0"
