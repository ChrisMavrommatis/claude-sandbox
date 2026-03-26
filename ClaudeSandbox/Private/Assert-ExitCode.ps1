function Assert-ExitCode([string]$errorMessage) {
    if ($LASTEXITCODE -ne 0) {
        $divider = "-" * 60
        Write-Host ""
        Write-Host "  ERROR: $errorMessage" -ForegroundColor Red
        Write-Host $divider -ForegroundColor DarkGray
        exit 1
    }
}
