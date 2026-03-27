#Requires -Version 5.1
<#
.SYNOPSIS
    Changes the active managed policy in claude-sandbox.
.DESCRIPTION
    Interactive picker to select and deploy a managed policy without reinstalling.
    Run from an elevated PowerShell prompt.
#>

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\ClaudeSandbox\ClaudeSandbox.psd1" -Force
. "$PSScriptRoot\sandbox-config.ps1"

# -- Interactive policy picker ---------------------------------------------------------
$policiesDir = Join-Path $PSScriptRoot "ClaudeSandbox\Assets\policies"
$policyDirs  = Get-ChildItem -Path $policiesDir -Directory
if ($policyDirs.Count -eq 0) {
    Write-Error "No policies found in '$policiesDir'."
    exit 1
}

Write-Host ""
Write-Host "  Available policies:" -ForegroundColor Cyan
for ($i = 0; $i -lt $policyDirs.Count; $i++) {
    Write-Host "  [$($i+1)] $($policyDirs[$i].Name)" -ForegroundColor Gray
}
Write-Host ""

$index = 0
do {
    $raw   = Read-Host "Select a policy (1-$($policyDirs.Count))"
    $valid = [int]::TryParse($raw.Trim(), [ref]$index) -and $index -ge 1 -and $index -le $policyDirs.Count
    if (-not $valid) {
        Write-Host "  Invalid selection. Enter a number between 1 and $($policyDirs.Count)." -ForegroundColor Red
    }
} while (-not $valid)

$selected = $policyDirs[$index - 1].Name

Set-SandboxPolicy -Config $Config -PolicyName $selected
