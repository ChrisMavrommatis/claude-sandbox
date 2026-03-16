#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the Claude Code WSL2 sandbox environment.
.DESCRIPTION
    Creates a Debian bookworm-slim WSL2 distro with Claude Code installed
    and project-switching helpers configured.
    Prerequisites: WSL2 feature enabled, Podman for Windows installed.
    Run from an elevated PowerShell prompt.
#>

# ═══════════════════════════════════════════════════════════════════════════════
# Install-ClaudeSandbox.ps1 — Installation script
# Run this script once to set up the sandbox.
# It reads configuration from sandbox-config.ps1, which you should edit first.
# ═══════════════════════════════════════════════════════════════════════════════

# -- Ensure required files are present ------------------------------------------------
$RequiredFiles = @(
    "sandbox-config.ps1",
    "wsl.conf",
    "netvolution.sh"
)
foreach ($file in $RequiredFiles) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $file))) {
        Write-Error "Required file '$file' not found in script directory. Please ensure all files are present."
        exit 1
    }
}

# -- Load configuration ---------------------------------------------------------
. "$PSScriptRoot\sandbox-config.ps1"

## -- Configuration values (edit sandbox-config.ps1) --------------------------------
$InstallDir = "$env:LOCALAPPDATA\WSL\$DistroName"
$TarPath = "C:\temp\claude-sandbox.tar"

$Netvolution6Path  = Join-Path $ProjectsPath "Netvolution6"
$ProjectsDrvfs     = $ProjectsPath.Replace("\", "\\")
$Netvolution6Drvfs = $Netvolution6Path.Replace("\", "\\")

function Write-Step([string]$msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

## -- Prerequisites check ---------------------------------------------------------
if (-not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Enabled") {
    Write-Error "WSL is not enabled. Please enable it and try again."
    exit 1
}

if(-not (Get-Command $ContainerRuntime -ErrorAction SilentlyContinue)) {
    Write-Error "$ContainerRuntime is not installed or not in PATH. Please install it and try again."
    exit 1
}

## -- Step 1: WSL  ------------------------------------------------------------------
Write-Step "Configuring WSL..."

wsl --install --no-distribution 2>$null
wsl --set-default-version 2

## -- Step 2: Create WSL distro ------------------------------------------------------
Write-Step "Creating WSL distro '$DistroName' with $DistroImage image..."

$ContainerId = ($containerRuntime create $DistroImage 2>&1).Trim()
if (-not $ContainerId) {
    Write-Error "Failed to create container. Please check your container runtime installation."
    exit 1
}

$containerRuntime export $ContainerId --output=$TarPath
if (-not (Test-Path $TarPath)) {
    Write-Error "Failed to export container to tarball."
    exit 1
}

$containerRuntime rm $ContainerId | Out-Null

Write-Step "Importing tarball as WSL distro '$DistroName'..."
wsl --import $DistroName $InstallDir $TarPath --version 2

## -- Step 3: Configure the sandbox --------------------------------------------------
Write-Step "Configuring the sandbox environment..."

$wslConfContent = Get-Content "$PSScriptRoot\wsl.conf" | ForEach-Object {
    $_ -replace "__DistroName__", $DistroName -replace "__Username__", $Username
}

### Run root setup script to install packages, create user, and configure wsl.conf
Write-Step "Running root setup script inside the sandbox (this may take a few minutes)..."
$RootSetupScript = @"
set -e

echo 'Installing packages...'
apt-get update
apt-get upgrade
apt-get install -y $($Packages -join " ")

echo 'Creating user and setting password...'
useradd -m -s /bin/bash $Username
printf '%s:%s\n' '$Username' '$UserPassword' | chpasswd

echo 'Configuring sudoers...'
usermod -aG sudo $Username

echo 'Setting up /etc/wsl.conf...'
echo "$wslConfContent" > /etc/wsl.conf
"@
$RootSetupScript | wsl -d $DistroName --user root -- bash
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to run root setup script. Please check the output above for details."
    exit 1
}


Write-Step "Restarting distro (applying wsl.conf)..."
wsl --terminate $DistroName
Start-Sleep -Seconds 5

### Run user setup script to install Claude Code and configure bashrc extensions
write-Step "Running user setup script inside the sandbox (this may take a few minutes)..."
$UserSetupScript = @"
echo 'Install bashrc extension...'
mkdir -p ~/.bashrc.d
mkdir -p ~/current-project
mkdir -p ~/netvolution6
mkdir -p ~/projects

echo 'export PATH="`$HOME/.local/bin:`$PATH"' >> ~/.bashrc && source ~/.bashrc
"@

$UserSetupScript | wsl -d $DistroName --user $Username -- bash
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to run user setup script. Please check the output above for details."
    exit 1
}

Write-Step "Installing Claude Code inside the sandbox..."
"curl -fsSL https://claude.ai/install.sh | bash" | wsl -d $DistroName --user $Username -- bash
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install Claude Code. Please check the output above for details."
    exit 1
}




