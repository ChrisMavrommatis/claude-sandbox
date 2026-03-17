#Requires -Version 5.1
<#
.SYNOPSIS
    Changes the active bashrc profile in claude-sandbox.
.DESCRIPTION
    Use this script to change the active bashrc profile in claude-sandbox without needing a full reinstall.
    Copies the selected profile to ~/.bashrc, then tells you to re-source.
    Run from an elevated PowerShell prompt (or normal if WSL doesn't need sudo).
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

$divider = "-" * 60

## -- Start of script -------------------------------------------------------------------
Write-Host ""
Write-Host $divider -ForegroundColor DarkGray
Write-Host "  Claude Sandbox Change Bashrc Profile" -ForegroundColor White
Write-Host "  Distro : $DistroName"                 -ForegroundColor DarkGray
Write-Host "  User : $Username"                     -ForegroundColor DarkGray   
Write-Host "  Runtime : $ContainerRuntime"          -ForegroundColor DarkGray
Write-Host $divider -ForegroundColor DarkGray
Write-Host ""

## -- Select and apply bashrc profile -----------------------------------------------
Write-Step "Select bashrc profile..."

### Test for bashrc folder
$BashrcSourceDir = Join-Path $PSScriptRoot "bashrc"
if (-not (Test-Path $BashrcSourceDir)) {
    Write-Error "Bashrc source directory '$BashrcSourceDir' not found."
    exit 1
}

### Get bashrc profile files
$BashrcFiles = Get-ChildItem -Path $BashrcSourceDir -Filter "*.sh" -File
if ($BashrcFiles.Count -eq 0) {
    Write-Error "No bashrc profile files found in '$BashrcSourceDir'."
    exit 1
}

### List profiles
Write-Info "Found $($BashrcFiles.Count) profile(s):"
for ($i = 0; $i -lt $BashrcFiles.Count; $i++) {
    Write-Host "  [$($i+1)] $($BashrcFiles[$i].Name)" -ForegroundColor Gray
}
Write-Host ""

### Select profile
$index = 0
do {
    $raw = Read-Host "Select a profile (1-$($BashrcFiles.Count))"
    $valid = [int]::TryParse($raw.Trim(), [ref]$index) -and $index -ge 1 -and $index -le $BashrcFiles.Count
    if (-not $valid) {
        Write-Host "  Invalid selection. Enter a number between 1 and $($BashrcFiles.Count)." -ForegroundColor Red
    }
} while (-not $valid)

$selectedFile = $BashrcFiles[$index - 1]
Write-Ok "Selected: $($selectedFile.Name)"

### -- Write selected profile to ~/.bashrc ------------------------------------------------
Write-Info "Writing $($selectedFile.Name) to ~/.bashrc..."
$content = (Get-Content $selectedFile.FullName -Raw -Encoding UTF8) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText(
    "\\wsl$\$DistroName\home\$Username\.bashrc",
    $content,
    (New-Object System.Text.UTF8Encoding $false)
)
Write-Ok "Profile '$($selectedFile.Name)' written to ~/.bashrc"
