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

# -- Ensure script is running with Administrator privileges ----------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
    exit 1
}

# -- Ensure required files are present ------------------------------------------------
$RequiredFiles = @(
    "common.ps1",
    "sandbox-config.ps1",
    "wsl.conf",
    "profiles\default.sh",
    "workflows\default.sh"
)
foreach ($file in $RequiredFiles) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $file))) {
        Write-Error "Required file '$file' not found in script directory. Please ensure all files are present."
        exit 1
    }
}

# -- Load configuration ---------------------------------------------------------
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\sandbox-config.ps1"

## -- Configuration values (edit sandbox-config.ps1) --------------------------------
# Make sure temp directory exists
$tempDir = Join-Path $PSScriptRoot "../temp"
Ensure-DirectoryExists $tempDir

$TarPath = Join-Path $tempDir "claude-sandbox.tar"

$divider = "-" * 60

## -- Start of script -------------------------------------------------------------------
Write-Host ""
Write-Host $divider -ForegroundColor DarkGray
Write-Host "  Claude Sandbox Installer"     -ForegroundColor White
Write-Host "  Distro : $DistroName"         -ForegroundColor DarkGray
Write-Host "  User : $Username"             -ForegroundColor DarkGray   
Write-Host "  Runtime : $ContainerRuntime"  -ForegroundColor DarkGray
Write-Host $divider -ForegroundColor DarkGray
Write-Host ""

## -- Prerequisites check ---------------------------------------------------------
Write-Step "Checking prerequisites..."

### Check if WSL is enabled
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -ne "Enabled") {
    Write-Host "  ERROR: WSL is not enabled. Please enable it and try again." -ForegroundColor Red
    exit 1
}
Write-Info "WSL feature enabled"

### Check if Container Runtime is installed
if(-not (Get-Command $ContainerRuntime -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: $ContainerRuntime is not installed or not in PATH." -ForegroundColor Red
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
## Remove image 
$imageId = & $ContainerRuntime images -q $DistroImage
if ($imageId) {
    Write-Info "Removing container image..."
    & $ContainerRuntime rmi $imageId | Out-Null
}
Write-Ok "Container removed"

### Import tarball to WSL
Write-Info "Importing '$DistroImage' as WSL distro '$DistroName'..."
Ensure-DirectoryExists $InstallDir
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
$escapedPassword = $UserPassword -replace "'", "'\''"
Execute-InSandbox "useradd -m -s /bin/bash $Username && printf '%s:%s\n' '$Username' '$escapedPassword' | chpasswd && usermod -aG sudo $Username" "root"
Write-Ok "User '$Username' created and added to sudo group"

### Write wsl.conf to set default user and other settings
Write-Info "Writing wsl.conf..."
$wslConfContent = (Get-Content "$PSScriptRoot\wsl.conf" -Raw) `
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
wsl --terminate $DistroName
Start-Sleep -Seconds 5
Write-Ok "Distro restarted"

### Configure PATH in .bashrc
Write-Info "Configuring user environment..."
Add-Content -Path "\\wsl$\$DistroName\home\$Username\.bashrc" `
            -Value 'export PATH="$HOME/.local/bin:$PATH"' `
            -Encoding UTF8
Write-Ok "Directories and PATH configured"

### Restart the distro to apply PATH changes
Write-Info "Restarting distro to apply PATH changes..."
wsl --terminate $DistroName
Start-Sleep -Seconds 5
Write-Ok "Distro restarted"

### Configure persistence directory and mount
Write-Info "Creating .claude persistence directory..."
Execute-InSandbox "mkdir -p ~/.claude" $Username
Write-Ok ".claude directory created"

### Write fstab entry to mount Windows folder as ~/.claude in the sandbox
Write-Info "Configuring persistence directory mount in wsl.conf..."
Execute-InSandbox "rm -f /tmp/claude-fstab.tmp" "root"
$fstabDirLine = "$ClaudePersistenceDir /home/$Username/.claude drvfs uid=1000,gid=1000,umask=022,metadata 0 0`n"
[System.IO.File]::WriteAllText(
    "\\wsl$\$DistroName\tmp\claude-fstab.tmp",
    $fstabDirLine,
    (New-Object System.Text.UTF8Encoding $false)
)
Execute-InSandbox "cat /tmp/claude-fstab.tmp >> /etc/fstab && rm /tmp/claude-fstab.tmp" "root"
Write-Ok "Persistence directory mount configured"

### Create symlink for ~/.claude.json persistence file
Write-Info "Creating symlink for ~/.claude.json persistence file..."
Execute-InSandbox "ln -sf /home/$Username/.claude/.claude.json /home/$Username/.claude.json" $Username
Write-Ok "Symlink for ~/.claude.json created"

### Restart the distro to apply fstab changes
Write-Info "Restarting distro to apply FSTAB changes..."
wsl --terminate $DistroName
Start-Sleep -Seconds 5
Write-Ok "Distro restarted"

### Install Claude Code
Write-Info "Installing Claude Code..."
Execute-InSandbox "curl -fsSL https://claude.ai/install.sh | bash" $Username
Write-Ok "Claude Code installed"

### Create Necessary Directories
Write-Info "Creating projects and .bashrc.d directories..."
Execute-InSandbox "mkdir -p /home/$Username/projects" $Username
Execute-InSandbox "mkdir -p /home/$Username/.bashrc.d" $Username
Write-Ok "Directories created"

## -- Step 4: Add Default Profile and Workflow -------------------------------------------------
Write-Step "Adding default bashrc profile and workflow..."

### Add default bashrc profile
Write-Info "Adding default bashrc profile..."
$profileContent = (Get-Content "$PSScriptRoot\profiles\default.sh" -Raw -Encoding UTF8) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText(
    "\\wsl$\$DistroName\home\$Username\.bashrc",
    $profileContent,
    (New-Object System.Text.UTF8Encoding $false)
)
Write-Ok "Default bashrc profile added"

### Add default workflow profile
Write-Info "Adding default workflow profile..."
$workflowContent = (Get-Content "$PSScriptRoot\workflows\default.sh" -Raw -Encoding UTF8) `
    -replace "__PROJECTS_DRVFS__", $ProjectsPath.Replace("\", "\\") `
    -replace "`r`n", "`n"  # Ensure Unix line endings

[System.IO.File]::WriteAllText(
    "\\wsl$\$DistroName\home\$Username\.bashrc.d\workflow.sh",
    $workflowContent,
    (New-Object System.Text.UTF8Encoding $false)
)
Write-Ok "Default workflow profile added"


## -- Step 5: Cleanup temp files ----------------------------------------------------------------
Write-Step "Step 5: Cleaning up temporary files..."

### Remove temporary files
Write-Info "Removing temporary files..."
### Remote tempDir and contents
Remove-Item $tempDir -Recurse -ErrorAction SilentlyContinue
Execute-InSandbox "rm -f /tmp/claude-fstab.tmp" "root"
Write-Ok "Temporary files cleaned up"


## -- Done -------------------------------------------------------------------------------
Write-Host ""
Write-Host "==============================================================================="
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Launch   : wsl -d $DistroName" -ForegroundColor White
Write-Host "  Run      : claude" -ForegroundColor White
Write-Host "  Uninstall : wsl --unregister $DistroName" -ForegroundColor White
Write-Host "==============================================================================="
Write-Host ""

## -- Next steps -----------------------------------------------------------------------