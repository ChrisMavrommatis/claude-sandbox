function Set-SandboxPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$PolicyName
    )

    $DistroName  = $Config.DistroName
    $policiesDir = Get-AssetPath "policies"
    $policyDir   = Join-Path $policiesDir $PolicyName

    if (-not (Test-Path "$policyDir")) {
        Write-Error "Policy '$PolicyName' not found in '$policiesDir'."
        exit 1
    }

    $settingsPath = Join-Path $policyDir "settings.json"
    $policyPath   = Join-Path $policyDir "policy.md"

    foreach ($f in @($settingsPath, $policyPath)) {
        if (-not (Test-Path "$f")) {
            Write-Error "Policy '$PolicyName' is missing file: $(Split-Path $f -Leaf)"
            exit 1
        }
    }

    Invoke-InSandbox $DistroName "mkdir -p /etc/claude-code"

    # Deploy managed settings [I-013, S-021]
    Write-Info "Writing managed settings ($PolicyName)..."
    $settingsContent = Get-Content $settingsPath -Raw -Encoding UTF8
    Write-FileToDistro $DistroName "/tmp/managed-settings.json" $settingsContent
    Invoke-InSandbox $DistroName "mv /tmp/managed-settings.json /etc/claude-code/managed-settings.json && chmod 644 /etc/claude-code/managed-settings.json"

    # Deploy managed policy [I-014]
    Write-Info "Writing managed policy ($PolicyName)..."
    $policyContent = Get-Content $policyPath -Raw -Encoding UTF8
    Write-FileToDistro $DistroName "/tmp/managed-policy.md" $policyContent
    Invoke-InSandbox $DistroName "mv /tmp/managed-policy.md /etc/claude-code/CLAUDE.md && chmod 644 /etc/claude-code/CLAUDE.md"

    Write-Ok "Policy '$PolicyName' deployed"
}
