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

    # -- Re-deploy managed settings and policy [I-013, I-014] ------------------------------
    Write-Step "Re-deploying managed settings and policy..."
    Invoke-InSandbox $DistroName "mkdir -p /etc/claude-code"
    $managedSettingsPath = Get-AssetPath "managed-settings.json"
    $managedSettingsContent = Get-Content $managedSettingsPath -Raw
    Write-FileToDistro $DistroName "/etc/claude-code/managed-settings.json" $managedSettingsContent
    $managedPolicyPath = Get-AssetPath "managed-policy.md"
    $managedPolicyContent = Get-Content $managedPolicyPath -Raw
    Write-FileToDistro $DistroName "/etc/claude-code/CLAUDE.md" $managedPolicyContent
    Write-Ok "Managed settings and policy re-deployed"

    # -- Verify ---------------------------------------------------------------------------
    Write-Step "Verifying sandbox..."
    Test-Sandbox -Config $Config
}
