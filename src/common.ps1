# ═══════════════════════════════════════════════════════════════════════════════
# Claude Sandbox — Common functions and configuration
# This file is imported by all other scripts.
# It contains common functions and variables used across the installer
# and configuration scripts.
# ═══════════════════════════════════════════════════════════════════════════════

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "  >> $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "     OK  $msg" -ForegroundColor Green
}

function Write-Info([string]$msg) {
    Write-Host "     --  $msg" -ForegroundColor DarkGray
}

function Check-ExitCode([string]$errorMessage) {
    if ($LASTEXITCODE -ne 0) {
        $sep = if ($divider) { $divider } else { "-" * 60 }
        Write-Host ""
        Write-Host "  ERROR: $errorMessage" -ForegroundColor Red
        Write-Host $sep -ForegroundColor DarkGray
        exit 1
    }
}

function Execute-InSandbox([string]$command, [string]$user = $Username) {
    wsl -d $DistroName --user $user -- bash -c $command
    Check-ExitCode "Command '$command' failed in sandbox. Check the output above for details."
}