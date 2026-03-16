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
    "bashrc/netvolution.sh"
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
# Make sure temp directory exists
$tempDir = Join-Path $PSScriptRoot "../temp"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

$InstallDir = "$env:LOCALAPPDATA\WSL\$DistroName"
$TarPath = Join-Path $tempDir "claude-sandbox.tar"


$Netvolution6Path  = Join-Path $ProjectsPath "Netvolution6"
$ProjectsDrvfs     = $ProjectsPath.Replace("\", "\\")
$Netvolution6Drvfs = $Netvolution6Path.Replace("\", "\\")

$divider = "-" * 60

## -- Helper functions ---------------------------------------------------------
function Write-Header {
    Write-Host ""
    Write-Host $divider -ForegroundColor DarkGray
    Write-Host "  Claude Sandbox Installer"     -ForegroundColor White
    Write-Host "  Distro : $DistroName"         -ForegroundColor DarkGray
    Write-Host "  User : $Username"             -ForegroundColor DarkGray   
    Write-Host "  Runtime : $ContainerRuntime"  -ForegroundColor DarkGray
    Write-Host $divider -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "  >> $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "     OK  $msg" -ForegroundColor Green
}

function Write-Info([string]$msg) {
    Write-Host "     --  $msg" -ForegroundColor DarkGray
}

function Check-ExitCode([string]$errorMessage) {
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ERROR: $errorMessage" -ForegroundColor Red
        Write-Host $divider -ForegroundColor DarkGray
        exit 1
    }
}

function Execute-InSandbox([string]$command, [string]$user = $Username) {
    wsl -d $DistroName --user $user -- bash -c $command
    Check-ExitCode "Command '$command' failed in sandbox. Check the output above for details."
}

## -- Start of script -------------------------------------------------------------------
Write-Header

## -- Prerequisites check ---------------------------------------------------------
Write-Step "Checking prerequisites..."

if (-not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Enabled") {
    Write-Host "  ERROR:WSL is not enabled. Please enable it and try again." -ForegroundColor Red
    exit 1
}
Write-Info "WSL feature enabled"

if(-not (Get-Command $ContainerRuntime -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR:$ContainerRuntime is not installed or not in PATH." -ForegroundColor Red
    exit 1
}
Write-Info "$ContainerRuntime found"

Write-Ok "Prerequisites check passed"

## -- Step 1: WSL  ------------------------------------------------------------------
Write-Step "Step 1: Setting up WSL2 and creating distro..."

### Install WSL2 if not already installed
Write-Info "Installing WSL2 (if not already installed)..."
wsl --install --no-distribution 2>$null
wsl --set-default-version 2

Write-Ok "Step 1 complete: WSL2 is set up"

## -- Step 2: Create WSL distro ------------------------------------------------------
Write-Step "Step 2:Creating container image from $DistroImage..."

### Create container
Write-Info "Creating container from '$DistroImage'..."
$ContainerId = & $ContainerRuntime create $DistroImage
if (-not $ContainerId) {
    Write-Host "  ERROR:Failed to create container. Check your container runtime." -ForegroundColor Red
    exit 1
}
Write-Ok "Container created with ID $ContainerId"

### Export container to tarball
Write-Info "Exporting to tarball..."
& $ContainerRuntime export $ContainerId --output=$TarPath
Start-Sleep -Seconds 5
if (-not (Test-Path $TarPath)) {
    Write-Host "  ERROR:Failed to export container to tarball." -ForegroundColor Red
    exit 1
}
Write-Ok "Container exported to $TarPath"


### Cleanup container
Write-Info "Cleaning up container..."
& $ContainerRuntime rm $ContainerId | Out-Null
Write-Ok "Container removed"


### Import tarball to WSL
Write-Info "Importing '$DistroImage' as WSL distro '$DistroName'..."
wsl --import $DistroName $InstallDir $TarPath --version 2
Write-Ok "Distro imported to $InstallDir"


Write-Ok "Step 2 complete: WSL distro '$DistroName' created from '$DistroImage'"

## -- Step 3: Configure the sandbox --------------------------------------------------
Write-Step "Step 3: Configuring the sandbox environment..."

### Install packages
Write-Info "Installing Packages"
Execute-InSandbox "apt-get update && apt-get upgrade -y && apt-get install -y $($Packages -join ' ')" "root"
Write-Ok "Packages installed"

### Create user and set password
Write-Info "Creating user '$Username'..."
Execute-InSandbox "useradd -m -s /bin/bash $Username && printf '%s:%s\n' '$Username' '$UserPassword' | chpasswd && usermod -aG sudo $Username" "root"
Write-Ok "User '$Username' created and added to sudo group"

### Write wsl.conf to set default user and other settings
Write-Info "Writing wsl.conf..."
$wslConfContent = (Get-Content "$PSScriptRoot\wsl.conf" -Raw) `
    -replace "__DistroName__", $DistroName `
    -replace "__Username__",   $Username `
    -replace "`r`n", "`n"  # Ensure Unix line endings   
    
$wslConfTempPath = Join-Path $tempDir "wsl.conf"
[System.IO.File]::WriteAllText($wslConfTempPath, $wslConfContent, (New-Object System.Text.UTF8Encoding $false))
Copy-Item $wslConfTempPath "\\wsl$\$DistroName\etc\wsl.conf"
Check-ExitCode "Failed to write wsl.conf."
Write-Ok "wsl.conf written"

### Restart the distro to apply wsl.conf changes
Write-Info "Restarting distro to apply wsl.conf..."
wsl --terminate $DistroName
Start-Sleep -Seconds 5
Write-Ok "Distro restarted"

### Run user setup script
Write-Info "Configuring user environment..."

Execute-InSandbox "mkdir -p ~/.bashrc.d" $Username
Execute-InSandbox "mkdir -p ~/current-project" $Username
Execute-InSandbox "mkdir -p ~/netvolution6" $Username
Execute-InSandbox "mkdir -p ~/projects" $Username
Execute-InSandbox 'echo `export PATH="$HOME/.local/bin:$PATH"` >> ~/.bashrc' $Username
Write-Ok "Directories and PATH configured"

### Install Claude Code
Write-Info "Installing Claude Code..."
Execute-InSandbox "curl -fsSL https://claude.ai/install.sh | bash" $Username
Write-Ok "Claude Code installed"

### Add bashrc extensions for project switching and Netvolution6 access
Write-Step "Step 4: Adding bashrc extensions for project switching and Netvolution6 access..."


Write-Info "Writing netvolution.sh bashrc extension..."
$netvolutionBashrcContent = (Get-Content "$PSScriptRoot\bashrc\netvolution.sh" -Raw) `
    -replace "__PROJECTS_DRVFS__",    $ProjectsDrvfs `
    -replace "__NETVOLUTION6_DRVFS__", $Netvolution6Drvfs `
    -replace "`r`n", "`n"  # Ensure Unix line endings
$netvolutionBashrcTempPath = Join-Path $tempDir "netvolution.sh"
[System.IO.File]::WriteAllText($netvolutionBashrcTempPath, $netvolutionBashrcContent, (New-Object System.Text.UTF8Encoding $false))
Copy-Item $netvolutionBashrcTempPath "\\wsl$\$DistroName\home\$Username\.bashrc.d\netvolution.sh"
Check-ExitCode "Failed to copy netvolution.sh to sandbox." 
Write-Ok "netvolution.sh bashrc extension deployed"


Write-Info "Configuring .bashrc to source netvolution.sh..."
$block = @'
if [ -f "$HOME/.bashrc.d/netvolution.sh" ]; then
    . "$HOME/.bashrc.d/netvolution.sh"
fi

# uncomment to add multiple entries in bashrc
# if [ -d "$HOME/.bashrc.d" ]; then
#     for f in "$HOME/.bashrc.d"/*.sh; do
#         [ -f "$f" ] && source "$f"
#     done
# fi

'@

$block = $block -replace "`r`n", "`n"  # Ensure Unix line endings

Execute-InSandbox "echo '$block' >> ~/.bashrc" $Username
Write-Ok ".bashrc configured to source netvolution.sh"

Write-Info "Applying bashrc changes..."
Execute-InSandbox "source ~/.bashrc" $Username
Write-Ok "Bashrc changes applied"

Write-Info "Index Projects"
## TODO Fix this
Execute-InSandbox "echo '$UserPassword' | sudo -S index-projects" $Username
Write-Ok "Projects indexed"

Write-Ok "Step 4 complete: bashrc extensions added"


## -- Step 5: Cleanup temp files ----------------------------------------------------------------
Write-Step "Step 5: Cleaning up temporary files..."

Write-Info "Removing temporary files..."
Remove-Item (Join-Path $tempDir "wsl.conf")      -ErrorAction SilentlyContinue
Remove-Item (Join-Path $tempDir "netvolution.sh") -ErrorAction SilentlyContinue
Remove-Item $TarPath                              -ErrorAction SilentlyContinue
Write-Ok "Temporary files cleaned up"

## -- Done -------------------------------------------------------------------------------
Write-Host ""
Write-Host "==============================================================================="
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Launch   : wsl -d $DistroName" -ForegroundColor White
Write-Host "  Run      : claude" -ForegroundColor White
Write-Host "  Projects : switch-project" -ForegroundColor White
Write-Host "==============================================================================="
Write-Host ""
