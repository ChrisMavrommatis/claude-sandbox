function Write-FileToDistro([string]$DistroName, [string]$LinuxPath, [string]$Content) {
    $unix = $Content -replace "`r`n", "`n"
    $uncPath = "\\wsl`$\$DistroName$($LinuxPath -replace '/', '\')"
    [System.IO.File]::WriteAllText($uncPath, $unix, (New-Object System.Text.UTF8Encoding $false))
}
