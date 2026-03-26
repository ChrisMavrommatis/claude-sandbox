#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the Claude Code WSL2 sandbox environment.
.DESCRIPTION
    Creates a Debian bookworm-slim WSL2 distro with Claude Code installed
    and project-switching helpers configured.
    Prerequisites: WSL2 feature enabled, Podman for Windows installed.
    Run from an elevated PowerShell prompt.
    It reads configuration from sandbox-config.ps1, which you should edit first.
#>

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\ClaudeSandbox\ClaudeSandbox.psd1" -Force
. "$PSScriptRoot\sandbox-config.ps1"

Assert-Administrator


## -- Preparation ------------------------------------------------
$tempDir = Join-Path $PSScriptRoot "temp"
Initialize-Directory $tempDir

$TarPath = Join-Path $tempDir "claude-sandbox.tar"
## -- Preparation ------------------------------------------------

Write-Banner "Claude Sandbox Installer" @{
    Distro   = $DistroName
    User     = $Username
    Runtime  = $ContainerRuntime
}

## -- Step 1: WSL -------------------------------------------------------------------
Write-Step "Step 1: WSL2 setup"

### Install WSL2 if not already installed
Write-Info "Installing WSL2 (if not already installed)..."
wsl --install --no-distribution 2>$null | Out-Null
Assert-ExitCode "Failed to install WSL2. Ensure WSL is enabled and try again."
wsl --set-default-version 2 | Out-Null
Assert-ExitCode "Failed to set WSL default version to 2."

Write-Ok "Step 1 Complete: WSL2 ready"
## -- Step 1: WSL --------------------------------------------------------------------

## -- Step 2: Create WSL distro ------------------------------------------------------
Write-Step "Step 2: Creating container image from $DistroImage..."

### Create container
Write-Info "Creating container from '$DistroImage'..."
$ContainerId = & $ContainerRuntime create $DistroImage
if (-not $ContainerId) {
    Write-Host "  ERROR: Failed to create container. Check your container runtime." -ForegroundColor Red
    exit 1
}
Write-Ok "Container created with ID $ContainerId"

### Export container to tarball
Write-Info "Exporting to tarball..."
& $ContainerRuntime export $ContainerId --output=$TarPath
if (-not (Test-Path $TarPath)) {
    Write-Host "  ERROR: Failed to export container to tarball." -ForegroundColor Red
    exit 1
}
Write-Ok "Container exported to $TarPath"

### Cleanup container
Write-Info "Cleaning up container..."
& $ContainerRuntime rm $ContainerId | Out-Null

### Remove image 
$imageId = & $ContainerRuntime images -q $DistroImage
if ($imageId) {
    Write-Info "Removing container image..."
    & $ContainerRuntime rmi $imageId | Out-Null
}
Write-Ok "Container removed"

### Import tarball to WSL
Write-Info "Importing '$DistroImage' as WSL distro '$DistroName'..."
Initialize-Directory $InstallDir
wsl --import $DistroName $InstallDir $TarPath --version 2 | Out-Null
Assert-ExitCode "Failed to import distro '$DistroName'. Check that the distro doesn't already exist (wsl --list)."
Write-Ok "Distro imported to $InstallDir"

Write-Ok "Step 2 Complete: WSL distro '$DistroName' created from '$DistroImage'"
## -- Step 2: Create WSL distro ------------------------------------------------------

## -- Step 3: Configure the sandbox --------------------------------------------------
Write-Step "Step 3: Configuring the sandbox environment..."

### Install packages
Write-Info "Installing Packages"
Invoke-InSandbox $DistroName "apt-get update && apt-get upgrade -y && apt-get install -y $($Packages -join ' ')" "root"
Write-Ok "Packages installed"

### Create user and set password
Write-Info "Creating user '$Username'..."
$escapedPassword = $UserPassword -replace "'", "'\'''" -replace '\$', '\$' -replace '`', '\`' -replace '"', '\"'
Invoke-InSandbox $DistroName "useradd -m -s /bin/bash $Username && printf '%s:%s\n' '$Username' '$escapedPassword' | chpasswd && usermod -aG sudo $Username" "root"
Write-Ok "User '$Username' created and added to sudo group"

### Write wsl.conf to set default user among other settings
Write-Info "Writing wsl.conf..."
$wslConfContent = (Get-Content "$PSScriptRoot\assets\wsl.conf" -Raw) `
    -replace "__DistroName__", $DistroName `
    -replace "__Username__",   $Username `
    -replace "`r`n", "`n"  # Ensure Unix line endings   
    
$wslConfTempPath = Join-Path $tempDir "wsl.conf"
[System.IO.File]::WriteAllText($wslConfTempPath, $wslConfContent, (New-Object System.Text.UTF8Encoding $false))
try {
    Copy-Item $wslConfTempPath "\\wsl$\$DistroName\etc\wsl.conf" -ErrorAction Stop
} catch {
    Write-Host "  ERROR: Failed to write wsl.conf: $_" -ForegroundColor Red
    exit 1
}
Write-Ok "wsl.conf written"

### Restart the distro to apply wsl.conf changes
Write-Info "Restarting distro to apply wsl.conf..."
Restart-Sandbox $DistroName
Write-Ok "Distro restarted"

### Configure persistence directory and mount
Write-Info "Creating .claude persistence directory..."
Invoke-InSandbox $DistroName "mkdir -p ~/.claude" $Username
Write-Ok ".claude directory created"

### Write fstab entry to mount Windows folder as ~/.claude in the sandbox
Write-Info "Configuring persistence directory mount in wsl.conf..."
$userUid = (wsl -d $DistroName --user $Username -- id -u).Trim()
$userGid = (wsl -d $DistroName --user $Username -- id -g).Trim()
Invoke-InSandbox $DistroName "rm -f /tmp/claude-fstab.tmp" "root"
$fstabDirLine = "$ClaudePersistenceDir /home/$Username/.claude drvfs uid=$userUid,gid=$userGid,umask=022,metadata 0 0`n"
[System.IO.File]::WriteAllText(
    "\\wsl$\$DistroName\tmp\claude-fstab.tmp",
    $fstabDirLine,
    (New-Object System.Text.UTF8Encoding $false)
)
Invoke-InSandbox $DistroName "cat /tmp/claude-fstab.tmp >> /etc/fstab && rm /tmp/claude-fstab.tmp" "root"
Write-Ok "Persistence directory mount configured"

### Create symlink for ~/.claude.json persistence file
Write-Info "Creating symlink for ~/.claude.json persistence file..."
Invoke-InSandbox $DistroName "ln -sf /home/$Username/.claude/.claude.json /home/$Username/.claude.json" $Username
Write-Ok "Symlink for ~/.claude.json created"

### Restart the distro to apply fstab changes
Write-Info "Restarting distro to apply FSTAB changes..."
Restart-Distro $DistroName
Write-Ok "Distro restarted"

### Install Claude Code
# Write-Info "Installing Claude Code..."
# Invoke-InSandbox $DistroName "curl -fsSL https://claude.ai/install.sh | bash" $Username
# Write-Ok "Claude Code installed"

### Create Necessary Directories
Write-Info "Creating projects and .bashrc.d directories..."
Invoke-InSandbox $DistroName "mkdir -p /home/$Username/projects" $Username
Invoke-InSandbox $DistroName "mkdir -p /home/$Username/.bashrc.d" $Username
Write-Ok "Directories created"

Write-Ok "Step 3 Complete: Sandbox environment configured with user, packages, and persistence"
## -- Step 3: Configure the sandbox --------------------------------------------------


## -- Step 4: Add Default Profile and Workflow -------------------------------------------------
Write-Step "Step 4: Adding default Windows Terminal profile and workflow..."


Write-Step "Step 4 Complete: Default Windows Terminal profile and workflow added"
## -- Step 4: Add Default Profile and Workflow -------------------------------------------------


## -- Step 5: Add Windows Terminal profile -------------------------------------------------
Write-Step "Step 5: Adding Windows Terminal profile for the sandbox..."

Write-Step "Step 5 Complete: Windows Terminal profile added"
## -- Step 5: Add Windows Terminal profile -------------------------------------------------


## -- Step 6: Cleanup temp files ----------------------------------------------------------------
Write-Step "Step 6: Cleaning up temporary files..."

### Remove temporary files
Write-Info "Removing temporary files..."
### Remote tempDir and contents
Remove-Item $tempDir -Recurse -ErrorAction SilentlyContinue
Invoke-InSandbox $DistroName "rm -f /tmp/claude-fstab.tmp" "root"
Write-Ok "Temporary files cleaned up"

Write-Ok "Step 6 Complete: Temporary files cleaned up"
## -- Step 6: Cleanup temp files ----------------------------------------------------------------

Write-Banner "Installation Complete" @{
    Launch     = "wsl -d $DistroName"
    Run        = "claude"
    Uninstall  = "./Uninstall-ClaudeSandbox.ps1"
}