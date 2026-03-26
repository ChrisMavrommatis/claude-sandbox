#Requires -Version 5.1
<#
.SYNOPSIS
    Changes the active bashrc profile in claude-sandbox.
.DESCRIPTION
    Interactive picker to select and deploy a bashrc profile without reinstalling.
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
}

# -- Interactive profile picker --------------------------------------------------------
$profilesDir = Join-Path $PSScriptRoot "ClaudeSandbox\Assets\profiles"
$profileFiles = Get-ChildItem -Path $profilesDir -Filter "*.sh" -File
if ($profileFiles.Count -eq 0) {
    Write-Error "No profiles found in '$profilesDir'."
    exit 1
}

Write-Host ""
Write-Host "  Available profiles:" -ForegroundColor Cyan
for ($i = 0; $i -lt $profileFiles.Count; $i++) {
    Write-Host "  [$($i+1)] $($profileFiles[$i].Name)" -ForegroundColor Gray
}
Write-Host ""

$index = 0
do {
    $raw = Read-Host "Select a profile (1-$($profileFiles.Count))"
    $valid = [int]::TryParse($raw.Trim(), [ref]$index) -and $index -ge 1 -and $index -le $profileFiles.Count
    if (-not $valid) {
        Write-Host "  Invalid selection. Enter a number between 1 and $($profileFiles.Count)." -ForegroundColor Red
    }
} while (-not $valid)

$selected = $profileFiles[$index - 1].Name

Set-SandboxProfile -Config $Config -ProfileName $selected
