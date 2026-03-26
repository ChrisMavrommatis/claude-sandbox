function Add-TerminalProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    $DistroName                = $Config.DistroName
    $TerminalProfileName       = $Config.TerminalProfileName
    $TerminalProfileIcon       = $Config.TerminalProfileIcon
    $TerminalProfileColorScheme = $Config.TerminalProfileColorScheme
    $TerminalProfileBackground = $Config.TerminalProfileBackground

    Write-Step "Adding Windows Terminal profile for '$DistroName'..."

    # -- Locate WSL distro profile in Windows Terminal fragments --------------------------
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
        if ($content -match '"name"\s*:\s*"' + [regex]::Escape($TerminalProfileName) + '"') {
            $profileFile = $file.FullName
            break
        }
    }

    if (-not $profileFile) {
        Write-Error "Windows Terminal profile for '$DistroName' not found. Ensure the profile exists."
        exit 1
    }
    Write-Ok "Found profile file: $profileFile"

    # -- Update profile properties --------------------------------------------------------
    Write-Info "Updating profile settings in '$profileFile'..."
    $json = $content | ConvertFrom-Json
    $profiles = $json.profiles

    $foundProfile = $profiles | Where-Object { $_.name -eq $DistroName }
    if (-not $foundProfile) {
        $foundProfile = $profiles | Where-Object { $_.name -eq $TerminalProfileName }
    }
    if (-not $foundProfile) {
        Write-Error "Profile with name '$DistroName' or '$TerminalProfileName' not found in JSON. Cannot update profile."
        exit 1
    }
    $foundProfile.name = $TerminalProfileName

    # Update or add background
    if ($foundProfile.PSObject.Properties.Name -contains "background") {
        $foundProfile.background = $TerminalProfileBackground
    } else {
        $foundProfile | Add-Member -MemberType NoteProperty -Name "background" -Value $TerminalProfileBackground
    }

    # Update or add colorScheme
    if ($foundProfile.PSObject.Properties.Name -contains "colorScheme") {
        $foundProfile.colorScheme = $TerminalProfileColorScheme
    } else {
        $foundProfile | Add-Member -MemberType NoteProperty -Name "colorScheme" -Value $TerminalProfileColorScheme
    }

    # Update or add icon
    if ($foundProfile.PSObject.Properties.Name -contains "icon") {
        $foundProfile.icon = $TerminalProfileIcon
    } else {
        $foundProfile | Add-Member -MemberType NoteProperty -Name "icon" -Value $TerminalProfileIcon
    }

    $profileGuid = $foundProfile.guid

    # Note: ConvertTo-Json may reformat the JSON file (whitespace, property ordering)
    $content = $json | ConvertTo-Json -Depth 10
    Set-Content -Path $profileFile -Value $content -Encoding UTF8
    Write-Ok "Updated Windows Terminal profile for '$DistroName' with name '$TerminalProfileName'."

    # -- Add profile to settings.json dropdown list if not already present -----------------
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
            guid   = $profileGuid
            hidden = $false
            name   = $TerminalProfileName
            source = "Microsoft.WSL"
        }
        $profilesList += $newProfile
        $content = $json | ConvertTo-Json -Depth 10
        Set-Content -Path $settingsFile -Value $content -Encoding UTF8
        Write-Ok "Added profile '$TerminalProfileName' to Windows Terminal dropdown list."
    } else {
        Write-Info "Profile '$TerminalProfileName' already present in Windows Terminal dropdown list. No changes made."
    }
}
