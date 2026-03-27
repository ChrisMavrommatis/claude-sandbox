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

$Config = @{
    DistroName                 = $DistroName
    DistroImage                = $DistroImage
    Username                   = $Username
    UserPassword               = $UserPassword
    ProjectsPath               = $ProjectsPath
    ClaudePersistenceDir       = $ClaudePersistenceDir
    ContainerRuntime           = $ContainerRuntime
    Packages                   = $Packages
    InstallDir                 = $InstallDir
    TerminalProfileName        = $TerminalProfileName
    TerminalProfileIcon        = $TerminalProfileIcon
    TerminalProfileColorScheme = $TerminalProfileColorScheme
    TerminalProfileBackground  = $TerminalProfileBackground
    GpuEnabled                 = $GpuEnabled
    SessionTimeout             = $SessionTimeout
}

# -- Confirmation prompts (interactive UI belongs in wrappers, not module) --------
Write-Host ""
Write-Host "  Distro: $DistroName" -ForegroundColor DarkGray
Write-Host "  Claude persistence data ($ClaudePersistenceDir) will NOT be removed." -ForegroundColor DarkGray
Write-Host ""

$confirm = Read-Host "  Remove '$DistroName'? [y/N]"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "  Aborted." -ForegroundColor Yellow
    exit 0
}

$RemoveInstallDir = $false
if (Test-Path $InstallDir) {
    $removeDirInput = Read-Host "  Also remove install directory ($InstallDir) from disk? [y/N]"
    $RemoveInstallDir = $removeDirInput -match '^[Yy]'
}

Uninstall-Sandbox -Config $Config -RemoveInstallDir:$RemoveInstallDir
