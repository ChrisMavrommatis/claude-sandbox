function Set-SandboxProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    Assert-Administrator

    $DistroName = $Config.DistroName
    $Username = $Config.Username

    Write-Banner "Claude Sandbox - Change Bashrc Profile" @{
        Distro = $DistroName
        User   = $Username
    }

    # -- Select profile -------------------------------------------------------------------
    Write-Step "Select bashrc profile..."

    $profilesDir = Get-AssetPath "profiles"
    $profileFiles = Get-ChildItem -Path $profilesDir -Filter "*.sh" -File
    if ($profileFiles.Count -eq 0) {
        Write-Error "No profiles found in '$profilesDir'."
        exit 1
    }

    Write-Info "Found $($profileFiles.Count) profile(s):"
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

    $selectedFile = $profileFiles[$index - 1]
    Write-Ok "Selected Profile: $($selectedFile.Name)"

    # -- Deploy profile -------------------------------------------------------------------
    $name = $selectedFile.Name
    Write-Info "Writing $name to ~/.bashrc..."
    $content = Get-Content $selectedFile.FullName -Raw -Encoding UTF8
    Write-FileToDistro $DistroName "/home/$Username/.bashrc" $content
    Write-Ok "Profile $name written to ~/.bashrc"
}
