#Requires -Version 5.1
<#
.SYNOPSIS
    Changes the workflow configuration in claude-sandbox.
.DESCRIPTION
    Interactive picker to select and deploy a workflow script without reinstalling.
    Performs token replacement for Windows paths.
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

Set-SandboxWorkflow -Config $Config
