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
    GpuEnabled                 = $GpuEnabled
    SessionTimeout             = $SessionTimeout
}

# -- Interactive workflow picker -------------------------------------------------------
$workflowsDir = Join-Path $PSScriptRoot "ClaudeSandbox\Assets\workflows"
$workflowFiles = Get-ChildItem -Path $workflowsDir -Filter "*.sh" -File
if ($workflowFiles.Count -eq 0) {
    Write-Error "No workflow files found in '$workflowsDir'."
    exit 1
}

Write-Host ""
Write-Host "  Available workflows:" -ForegroundColor Cyan
for ($i = 0; $i -lt $workflowFiles.Count; $i++) {
    Write-Host "  [$($i+1)] $($workflowFiles[$i].Name)" -ForegroundColor Gray
}
Write-Host ""

$index = 0
do {
    $raw = Read-Host "Select a workflow (1-$($workflowFiles.Count))"
    $valid = [int]::TryParse($raw.Trim(), [ref]$index) -and $index -ge 1 -and $index -le $workflowFiles.Count
    if (-not $valid) {
        Write-Host "  Invalid selection. Enter a number between 1 and $($workflowFiles.Count)." -ForegroundColor Red
    }
} while (-not $valid)

$selected = $workflowFiles[$index - 1].Name

Set-SandboxWorkflow -Config $Config -WorkflowName $selected
