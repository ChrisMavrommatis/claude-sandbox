#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the Claude Code WSL2 sandbox environment.
.DESCRIPTION
    Terminates and unregisters the WSL2 distro, optionally removes the install
    directory. Claude persistence data is never touched.
    Run from an elevated PowerShell prompt.
    Edit sandbox-config.ps1 first.
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
}

Uninstall-Sandbox -Config $Config
