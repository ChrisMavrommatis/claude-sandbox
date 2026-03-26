function Uninstall-Sandbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Assert-Administrator

    $DistroName           = $Config.DistroName
    $InstallDir           = $Config.InstallDir
    $ClaudePersistenceDir = $Config.ClaudePersistenceDir

    Write-Banner "Claude Sandbox Removal" @{
        Distro  = $DistroName
        InstDir = $InstallDir
    }

    Write-Host "  Claude persistence data ($ClaudePersistenceDir) will NOT be removed." -ForegroundColor DarkGray
    Write-Host ""

    # -- Confirm --------------------------------------------------------------------------
    $confirm = Read-Host "  Remove '$DistroName'? [y/N]"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "  Aborted." -ForegroundColor Yellow
        return
    }

    # -- Terminate distro -----------------------------------------------------------------
    Write-Step "Terminating distro..."
    wsl --terminate $DistroName 2>$null | Out-Null
    Write-Ok "Distro terminated"

    # -- Unregister distro ----------------------------------------------------------------
    Write-Step "Unregistering distro..."
    $registered = wsl -l --quiet 2>$null | Where-Object { $_.Trim() -eq $DistroName }
    if ($registered) {
        wsl --unregister $DistroName --quiet 2>$null
        Assert-ExitCode "Failed to unregister distro '$DistroName'."
        Write-Ok "Distro '$DistroName' unregistered"
    } else {
        Write-Info "Distro '$DistroName' was not registered - skipping"
    }

    # -- Optionally remove install directory -----------------------------------------------
    Write-Step "Install directory: $InstallDir"
    if (Test-Path $InstallDir) {
        $removeDir = Read-Host "  Remove install directory from disk? [y/N]"
        if ($removeDir -match '^[Yy]') {
            Remove-Item $InstallDir -Recurse -Force -ErrorAction Stop
            Write-Ok "Install directory removed"
        } else {
            Write-Info "Install directory kept"
        }
    } else {
        Write-Info "Install directory not found - skipping"
    }

    # -- Remove Windows Terminal profile ---------------------------------------------------
    Write-Step "Removing Windows Terminal profile..."
    Remove-TerminalProfile -Config $Config

    # -- Done -----------------------------------------------------------------------------
    Write-Host ""
    Write-Host "  Removal complete." -ForegroundColor Green
    Write-Host "  Your Claude data at $ClaudePersistenceDir is intact." -ForegroundColor DarkGray
    Write-Host ""
}
