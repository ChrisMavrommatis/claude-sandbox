function Restart-Sandbox {
    param (
        [Parameter(Mandatory=$true)]
        [string]$DistroName
    )
    wsl --terminate $DistroName | Out-Null
    Start-Sleep -Seconds 5
}