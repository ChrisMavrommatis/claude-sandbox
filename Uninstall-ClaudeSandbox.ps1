#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the Claude Code WSL2 sandbox environment.
.DESCRIPTION
    Terminates and unregisters the WSL2 distro, optionally removes the install
    directory from disk. Claude persistence data is never touched.
    Run from an elevated PowerShell prompt.
#>

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\ClaudeSandbox\ClaudeSandbox.psd1" -Force
. "$PSScriptRoot\sandbox-config.ps1"

# -- Confirmation prompts (interactive UI belongs in wrappers, not module) --------
Write-Host ""
Write-Host "  Distro: $($Config.DistroName)" -ForegroundColor DarkGray
Write-Host "  Claude persistence data ($($Config.ClaudePersistenceDir)) will NOT be removed." -ForegroundColor DarkGray
Write-Host ""

$confirm = Read-Host "  Remove '$($Config.DistroName)'? [y/N]"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "  Aborted." -ForegroundColor Yellow
    exit 0
}

$RemoveInstallDir = $false
if (Test-Path $Config.InstallDir) {
    $removeDirInput = Read-Host "  Also remove install directory ($($Config.InstallDir)) from disk? [y/N]"
    $RemoveInstallDir = $removeDirInput -match '^[Yy]'
}

Uninstall-Sandbox -Config $Config -RemoveInstallDir:$RemoveInstallDir
