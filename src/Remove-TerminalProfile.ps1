#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the Claude Sandbox terminal profile from Windows Terminal.
.DESCRIPTION
    Removes the Claude Sandbox profile entry from Windows Terminal's settings.json dropdown list.
    Prerequisites: WSL2 feature enabled, Windows Terminal installed.
    Run from a PowerShell prompt.
    It reads configuration from sandbox-config.ps1, which you should edit first.
#>

# -- Ensure script is running with Administrator privileges ----------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
    exit 1
}

# -- Ensure required files are present ------------------------------------------------
$RequiredFiles = @(
    "common.ps1",
    "sandbox-config.ps1"
)
foreach ($file in $RequiredFiles) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $file))) {
        Write-Error "Required file '$file' not found in script directory. Please ensure all files are present."
        exit 1
    }
}

# -- Load configuration ---------------------------------------------------------------
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\sandbox-config.ps1"

Write-Step "Removing Windows Terminal profile for '$DistroName'..."

# -- Remove entry from settings.json dropdown list ------------------------------------
$settingsFile = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsFile)) {
    Write-Error "Windows Terminal settings.json not found at '$settingsFile'. Ensure Windows Terminal is installed and you have launched it at least once."
    exit 1
}

Write-Info "Searching for profile in '$settingsFile'..."
$settingsJson = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
$profilesList = $settingsJson.profiles.list

$profile = $profilesList | Where-Object { $_.name -eq $TerminalProfileName }
if (-not $profile) {
    $profile = $profilesList | Where-Object { $_.name -eq $DistroName }
}
if (-not $profile) {
    Write-Info "Profile '$TerminalProfileName' not found in settings.json. Nothing to remove."
    exit 0
}

$settingsJson.profiles.list = @($profilesList | Where-Object { $_.guid -ne $profile.guid })
Set-Content -Path $settingsFile -Value ($settingsJson | ConvertTo-Json -Depth 10) -Encoding UTF8
Write-OK "Removed '$TerminalProfileName' from Windows Terminal dropdown list."

