function Invoke-InSandbox {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DistroName,
        
        [Parameter(Mandatory=$true)]
        [string]$Command,

        [Parameter(Mandatory=$false)]
        [string]$User = "root"
    )
    wsl -d $DistroName --user $User -- bash -c $Command `
        | ForEach-Object { Write-Host "       $_`r" -ForegroundColor DarkGray }
    Assert-ExitCode "Command failed in $DistroName : $Command"
}

