# build-and-push.ps1 - Build and push the dev container image to ACR
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

# Get Terraform outputs
Push-Location "$ProjectDir/terraform"

try {
    Write-Host "Getting Terraform outputs..."
    $ACR_SERVER = terraform output -raw container_registry_login_server 2>$null
    $ACR_USERNAME = terraform output -raw container_registry_username 2>$null
    $ACR_PASSWORD = terraform output -raw container_registry_password 2>$null

    if ([string]::IsNullOrEmpty($ACR_SERVER)) {
        Write-Error "Error: Could not get ACR credentials from Terraform.`nMake sure you have run 'terraform apply' first."
        exit 1
    }

    Write-Host "ACR Server: $ACR_SERVER"

    # Login to ACR
    Write-Host "Logging into Azure Container Registry..."
    $ACR_PASSWORD | docker login $ACR_SERVER -u $ACR_USERNAME --password-stdin

    # Build image
    Push-Location "$ProjectDir/docker"

    Write-Host ""
    Write-Host "Building devcontainer image..."
    docker build -t "$ACR_SERVER/devcontainer-dotnet:latest" `
        --platform linux/amd64 `
        .

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed"
        exit 1
    }

    # Push image
    Write-Host ""
    Write-Host "Pushing devcontainer image..."
    docker push "$ACR_SERVER/devcontainer-dotnet:latest"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker push failed"
        exit 1
    }

    Write-Host ""
    Write-Host "=== Build Complete ==="
    Write-Host "Image pushed:"
    Write-Host "  - $ACR_SERVER/devcontainer-dotnet:latest"
    Write-Host ""
    Write-Host "This image includes:"
    Write-Host "  - .NET SDK (latest)"
    Write-Host "  - Claude Code CLI"
    Write-Host "  - Happy CLI (for mobile Claude Code connectivity)"
    Write-Host "  - GitHub CLI"
}
finally {
    Pop-Location
    if ((Get-Location).Path -ne $ProjectDir) {
        Pop-Location
    }
}
