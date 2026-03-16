#Requires -Version 5.1
<#
.SYNOPSIS
    Pushes an updated netvolution.sh into an existing claude-sandbox WSL distro.
.DESCRIPTION
    Use this after editing netvolution.sh or sandbox-config.ps1 — no need to
    reinstall. Copies the file with paths injected, then tells you to re-source.
    Run from an elevated PowerShell prompt (or normal if WSL doesn't need sudo).
#>

. "$PSScriptRoot\sandbox-config.ps1"

# ─────────────────────────────────────────────────────────────────────────────

function Write-Step([string]$msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function ConvertTo-WslPath([string]$winPath) {
    $drive = $winPath[0].ToString().ToLower()
    $rest  = $winPath.Substring(2).Replace("\", "/")
    return "/mnt/$drive$rest"
}

# ── Checks ────────────────────────────────────────────────────────────────────
if (-not (Test-Path "$PSScriptRoot\netvolution.sh")) {
    Write-Error "netvolution.sh not found next to this script."
    exit 1
}

$distros = wsl -l -q 2>$null
if ($distros -notcontains $DistroName) {
    Write-Error "'$DistroName' is not installed. Run Install-ClaudeSandbox.ps1 first."
    exit 1
}

# ── Inject paths and write to temp ───────────────────────────────────────────
Write-Step "Preparing netvolution.sh..."
$NetvolutionContent = (Get-Content "$PSScriptRoot\netvolution.sh" -Raw) `
    .Replace("__PROJECTS_DRVFS__",    $ProjectsDrvfs) `
    .Replace("__NETVOLUTION6_DRVFS__", $Netvolution6Drvfs)

$NetvolutionTmp = "$env:TEMP\netvolution.sh"
[System.IO.File]::WriteAllText($NetvolutionTmp, $NetvolutionContent, (New-Object System.Text.UTF8Encoding $false))

# ── Copy into WSL ─────────────────────────────────────────────────────────────
# wsl.conf has automount disabled, so we pipe the file content via stdin instead
# of relying on /mnt/ paths.
Write-Step "Copying netvolution.sh into $DistroName..."

$CopyScript = @"
mkdir -p /home/$Username/.bashrc.d
cat > /home/$Username/.bashrc.d/netvolution.sh << 'SHEOF'
$NetvolutionContent
SHEOF
chown ${Username}:${Username} /home/$Username/.bashrc.d/netvolution.sh
echo 'Done.'
"@

$CopyScript | wsl -d $DistroName -u root -- bash
if ($LASTEXITCODE -ne 0) { Write-Error "Copy failed"; exit 1 }

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "netvolution.sh updated in $DistroName." -ForegroundColor Green
Write-Host ""
Write-Host "To apply in any open WSL sessions, run:"
Write-Host "  source ~/.bashrc"
