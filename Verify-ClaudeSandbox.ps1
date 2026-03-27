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

Test-Sandbox -Config $Config
