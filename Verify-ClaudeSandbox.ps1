#Requires -Version 5.1
<#
.SYNOPSIS
    Verifies the Claude Sandbox installation and security posture.
.DESCRIPTION
    Runs installation and security checks against the configured sandbox distro.
    Reports PASS/FAIL/WARN for each check with a summary at the end.
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

Test-Sandbox -Config $Config
