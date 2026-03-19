#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the Claude Code WSL2 sandbox environment.
.DESCRIPTION
    Terminates and unregisters the WSL2 distro, then optionally removes the
    install directory from disk. Reads distro name and install path from
    sandbox-config.ps1. Claude persistence data (ClaudePersistenceDir) is
    never touched — it lives on Windows and survives the removal.
    Run from an elevated PowerShell prompt.
#>

# -- Ensure script is running with Administrator privileges ----------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
    exit 1
}

# -- Load configuration ----------------------------------------------------------------
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\sandbox-config.ps1"

$divider = "-" * 60

Write-Host ""
Write-Host $divider -ForegroundColor DarkGray
Write-Host "  Claude Sandbox Removal" -ForegroundColor White
Write-Host "  Distro  : $DistroName"  -ForegroundColor DarkGray
Write-Host "  InstDir : $InstallDir"  -ForegroundColor DarkGray
Write-Host $divider -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Claude persistence data ($ClaudePersistenceDir) will NOT be removed." -ForegroundColor DarkGray
Write-Host ""

# -- Confirm ---------------------------------------------------------------------------
$confirm = Read-Host "  Remove '$DistroName'? [y/N]"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "  Aborted." -ForegroundColor Yellow
    exit 0
}

# -- Terminate distro ------------------------------------------------------------------
Write-Step "Terminating distro..."
wsl --terminate $DistroName 2>$null | Out-Null
Write-Ok "Distro terminated"

# -- Unregister distro -----------------------------------------------------------------
Write-Step "Unregistering distro..."
$registered = wsl -l --quiet 2>$null | Where-Object { $_.Trim() -eq $DistroName }
if ($registered) {
    wsl --unregister $DistroName --quiet 2>$null
    Check-ExitCode "Failed to unregister distro '$DistroName'."
    Write-Ok "Distro '$DistroName' unregistered"
} else {
    Write-Info "Distro '$DistroName' was not registered - skipping"
}

# -- Optionally remove install directory -----------------------------------------------
Write-Step "Install directory: $InstallDir"
if (Test-Path $InstallDir) {
    $removeDir = Read-Host "  Remove install directory from disk? [y/N]"
    if ($removeDir -eq 'y' -or $removeDir -eq 'Y') {
        Remove-Item $InstallDir -Recurse -Force -ErrorAction Stop
        Write-Ok "Install directory removed"
    } else {
        Write-Info "Install directory kept"
    }
} else {
    Write-Info "Install directory not found - skipping"
}


# -- Done ------------------------------------------------------------------------------
Write-Host ""
Write-Host "  Removal complete." -ForegroundColor Green
Write-Host "  Your Claude data at $ClaudePersistenceDir is intact." -ForegroundColor DarkGray
Write-Host ""
