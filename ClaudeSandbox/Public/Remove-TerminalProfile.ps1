function Remove-TerminalProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    $DistroName          = $Config.DistroName
    $TerminalProfileName = $Config.TerminalProfileName

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
        return
    }

    $settingsJson.profiles.list = @($profilesList | Where-Object { $_.guid -ne $profile.guid })
    # Note: ConvertTo-Json may reformat the JSON file (whitespace, property ordering)
    Set-Content -Path $settingsFile -Value ($settingsJson | ConvertTo-Json -Depth 10) -Encoding UTF8
    Write-Ok "Removed '$TerminalProfileName' from Windows Terminal dropdown list."
}
