function Update-Sandbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    Assert-Administrator

    $DistroName = $Config.DistroName
    $Username   = $Config.Username

    Write-Banner "Claude Sandbox Update" @{
        Distro = $DistroName
        User   = $Username
    }

    # -- Update packages ------------------------------------------------------------------
    Write-Step "Updating packages..."
    Invoke-InSandbox $DistroName "apt-get update && apt-get upgrade -y"
    Write-Ok "Packages updated"

    # -- Re-deploy profile and workflow [I-006, I-007] ------------------------------------
    Write-Step "Re-deploying profile and workflow..."
    Set-SandboxProfile -Config $Config -ProfileName "default.sh"
    Set-SandboxWorkflow -Config $Config -WorkflowName "default.sh"
    Write-Ok "Profile and workflow re-deployed"

    # -- Verify ---------------------------------------------------------------------------
    Write-Step "Verifying sandbox..."
    Test-Sandbox -Config $Config
}
