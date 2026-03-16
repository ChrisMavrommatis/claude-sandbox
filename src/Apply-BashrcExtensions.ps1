#Requires -Version 5.1
<#
.SYNOPSIS
    Pushes updated bashrc snippets into WSL.
.DESCRIPTION
    Use this after editing any snippets in ./bashrc to update the WSL environment without needing a full reinstall.
    Copies the files under ~/.bashrc.d, then tells you to re-source.
    Run from an elevated PowerShell prompt (or normal if WSL doesn't need sudo).
#>

# -- Ensure script is running with Administrator privileges ----------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
    exit 1
}


# -- Ensure required files are present ------------------------------------------------
$RequiredFiles = @(
    "common.ps1",
    "sandbox-config.ps1"
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
$BashrcDestDir = "/home/$Username/.bashrc.d"

$divider = "-" * 60

## -- Start of script -------------------------------------------------------------------
Write-Host ""
Write-Host $divider -ForegroundColor DarkGray
Write-Host "  Claude Sandbox Bashrc Extensions" -ForegroundColor White
Write-Host "  Distro : $DistroName"             -ForegroundColor DarkGray
Write-Host "  User : $Username"                 -ForegroundColor DarkGray   
Write-Host "  Runtime : $ContainerRuntime"      -ForegroundColor DarkGray
Write-Host $divider -ForegroundColor DarkGray
Write-Host ""

## -- Step 1: Find bashrc snippets ---------------------------------------------------------
Write-Step "Step 1: Finding bashrc snippets to apply..."

Write-Info "Does the bashrc source directory exist?"
$BashrcSourceDir = Join-Path $PSScriptRoot "bashrc"
if (-not (Test-Path $BashrcSourceDir)) {
    Write-Error "Bashrc source directory '$BashrcSourceDir' not found. Please ensure it exists and contains your bashrc snippets."
    exit 1
}
Write-Ok "Found bashrc source directory."

Write-Info "Finding bashrc snippet files in source directory..."
$BashrcFiles = Get-ChildItem -Path $BashrcSourceDir -File
if ($BashrcFiles.Count -eq 0) {
    Write-Error "No bashrc snippet files found in '$BashrcSourceDir'. Please add your bashrc snippets there."
    exit 1
}

Write-Ok "Found $($BashrcFiles.Count) bashrc snippet files."
foreach ($file in $BashrcFiles) {
    Write-Info "  - $($file.Name)"
}

## -- Step 2: Copy files into WSL ---------------------------------------------------------
Write-Step "Step 2: Copying bashrc snippets into WSL..."

# $Netvolution6Path  = Join-Path $ProjectsPath "Netvolution6"
# $ProjectsDrvfs     = $ProjectsPath.Replace("\", "\\")
# $Netvolution6Drvfs = $Netvolution6Path.Replace("\", "\\")

# Remove-Item (Join-Path $tempDir "netvolution.sh") -ErrorAction SilentlyContinue


# Execute-InSandbox "mkdir -p ~/.bashrc.d" $Username
# Execute-InSandbox "mkdir -p ~/current-project" $Username
# Execute-InSandbox "mkdir -p ~/netvolution6" $Username
# Execute-InSandbox "mkdir -p ~/projects" $Username

# Write-Info "Writing netvolution.sh bashrc extension..."
# $netvolutionBashrcContent = (Get-Content "$PSScriptRoot\bashrc\netvolution.sh" -Raw) `
#     -replace "__PROJECTS_DRVFS__",    $ProjectsDrvfs `
#     -replace "__NETVOLUTION6_DRVFS__", $Netvolution6Drvfs `
#     -replace "`r`n", "`n"  # Ensure Unix line endings
# $netvolutionBashrcTempPath = Join-Path $tempDir "netvolution.sh"
# [System.IO.File]::WriteAllText($netvolutionBashrcTempPath, $netvolutionBashrcContent, (New-Object System.Text.UTF8Encoding $false))
# Copy-Item $netvolutionBashrcTempPath "\\wsl$\$DistroName\home\$Username\.bashrc.d\netvolution.sh"
# Check-ExitCode "Failed to copy netvolution.sh to sandbox." 
# Write-Ok "netvolution.sh bashrc extension deployed"


# Write-Info "Configuring .bashrc to source netvolution.sh..."
# $block = @'
# if [ -f "$HOME/.bashrc.d/netvolution.sh" ]; then
#     . "$HOME/.bashrc.d/netvolution.sh"
# fi

# # uncomment to add multiple entries in bashrc
# # if [ -d "$HOME/.bashrc.d" ]; then
# #     for f in "$HOME/.bashrc.d"/*.sh; do
# #         [ -f "$f" ] && source "$f"
# #     done
# # fi

# '@

# $block = $block -replace "`r`n", "`n"  # Ensure Unix line endings

# Execute-InSandbox "echo '$block' >> ~/.bashrc" $Username
# Write-Ok ".bashrc configured to source netvolution.sh"

# Write-Info "Applying bashrc changes..."
# Execute-InSandbox "source ~/.bashrc" $Username
# Write-Ok "Bashrc changes applied"

# Write-Info "Index Projects"
# ## TODO Fix this
# Execute-InSandbox "echo '$UserPassword' | sudo -S index-projects" $Username
# Write-Ok "Projects indexed"

#  Projects : switch-project" -ForegroundColor White