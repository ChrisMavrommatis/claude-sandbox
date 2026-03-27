#Requires -Version 5.1
<#
.SYNOPSIS
    Updates packages and re-deploys profiles in the Claude Sandbox.
.DESCRIPTION
    Runs apt upgrade inside the sandbox and re-deploys the default bashrc profile
    and workflow. Verifies the sandbox at the end.
    Run from an elevated PowerShell prompt.
#>

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\ClaudeSandbox\ClaudeSandbox.psd1" -Force
. "$PSScriptRoot\sandbox-config.ps1"

Update-Sandbox -Config $Config
