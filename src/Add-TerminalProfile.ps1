#Requires -Version 5.1
<#
.SYNOPSIS
    Adds a terminal profile claude sandbox to Windows Terminal for WSL2.
.DESCRIPTION
    Adds a terminal profile for the Claude Sandbox WSL2 distro to Windows Terminal.
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

# -- Load configuration ---------------------------------------------------------
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\sandbox-config.ps1"

Write-Step "Adding Windows Terminal profile for '$DistroName'..."

## Search in C:\Users\mavrommatisc\AppData\Local\Microsoft\Windows Terminal\Fragments\Microsoft.WSL
## to find {guid}.json file for the distro... we need to read the json for this

Write-Info "Locating Windows Terminal profile for WSL distro '$DistroName'..."
$terminalSettingsPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL"
if (-not (Test-Path $terminalSettingsPath)) {
    Write-Error "Windows Terminal WSL settings directory not found at '$terminalSettingsPath'. Ensure Windows Terminal is installed and you have launched it at least once."
    exit 1
}
$profileFiles = Get-ChildItem -Path $terminalSettingsPath -Filter "*.json"
$profileFile = $null
foreach ($file in $profileFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    if ($content -match '"name"\s*:\s*"' + [regex]::Escape($DistroName) + '"') {
        $profileFile = $file.FullName
        break
    }
    if($content -match '"name"\s*:\s*"' + [regex]::Escape($TerminalProfileName) + '"') {
        $profileFile = $file.FullName
        break
    }
}

if (-not $profileFile) {
    Write-Error "Windows Terminal profile for '$DistroName' not found. Ensure the profile exists."
    exit 1
}
Write-OK "Found profile file: $profileFile"

Write-Info "Updating profile settings in '$profileFile'..."
#### Print file content for debugging
# $content | Write-Host -ForegroundColor Green

### parse json and update the fields
$json = $content | ConvertFrom-Json
$profiles = $json.profiles

 # contains name field with value $DistroName
$profile = $profiles | Where-Object { $_.name -eq $DistroName }
if (-not $profile) {
    $profile = $profiles | Where-Object { $_.name -eq $TerminalProfileName }
}
if (-not $profile) {
    Write-Error "Profile with name '$DistroName' or '$TerminalProfileName' not found in JSON. Cannot update profile."
    exit 1
}
$profile.name = $TerminalProfileName

### if background field exists, update it. Otherwise add it
if ($profile.PSObject.Properties.Name -contains "background") {
    $profile.background = "#5a0a22"
} else {
    $profile | Add-Member -MemberType NoteProperty -Name "background" -Value "#5a0a22"
}

### if colorScheme field exists, update it. Otherwise add it
if ($profile.PSObject.Properties.Name -contains "colorScheme") {
    $profile.colorScheme = "One Half Dark"
} else {
    $profile | Add-Member -MemberType NoteProperty -Name "colorScheme" -Value "One Half Dark"
}

### if icon field exists, update it. Otherwise add it
$iconPath =  "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png" 
if ($profile.PSObject.Properties.Name -contains "icon") {
    $profile.icon = $iconPath
} else {
    $profile | Add-Member -MemberType NoteProperty -Name "icon" -Value $iconPath
}

$profileGuid = $profile.guid

$content = $json | ConvertTo-Json -Depth 10
#### Print file content for debugging
# $content | Write-Host -ForegroundColor Green

Set-Content -Path $profileFile -Value $content -Encoding UTF8
Write-OK "Updated Windows Terminal profile for '$DistroName' with name '$TerminalProfileName'."


### Find the settings file and add the profile to the dropdown list if not already present
$settingsFile = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsFile)) {
    Write-Error "Windows Terminal settings file not found at '$settingsFile'. Ensure Windows Terminal is installed and you have launched it at least once."
    exit 1
}
Write-Info "Updating Windows Terminal settings in '$settingsFile'..."
$content = Get-Content -Path $settingsFile -Raw
$json = $content | ConvertFrom-Json
$profilesList = $json.profiles.list
if (-not ($profilesList | Where-Object { $_.guid -eq $profileGuid })) {
    $newProfile = @{
        guid = $profileGuid
        hidden = $false
        name = $TerminalProfileName
        source = "Microsoft.WSL"
    }
    $profilesList += $newProfile
    $content = $json | ConvertTo-Json -Depth 10
    Set-Content -Path $settingsFile -Value $content -Encoding UTF8
    Write-OK "Added profile '$TerminalProfileName' to Windows Terminal dropdown list."
} else {
    Write-Info "Profile '$TerminalProfileName' already present in Windows Terminal dropdown list. No changes made."
}