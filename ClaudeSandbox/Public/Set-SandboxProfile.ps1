function Set-SandboxProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )

    $DistroName = $Config.DistroName
    $Username   = $Config.Username

    $profilesDir = Get-AssetPath "profiles"
    $profilePath = Join-Path $profilesDir $ProfileName
    if (-not (Test-Path $profilePath)) {
        Write-Error "Profile '$ProfileName' not found in '$profilesDir'."
        exit 1
    }

    # Deploy bashrc profile [I-006]
    Write-Info "Writing $ProfileName to ~/.bashrc..."
    $content = Get-Content $profilePath -Raw -Encoding UTF8
    Write-FileToDistro $DistroName "/home/$Username/.bashrc" $content
    Write-Ok "Profile '$ProfileName' deployed to ~/.bashrc"
}
