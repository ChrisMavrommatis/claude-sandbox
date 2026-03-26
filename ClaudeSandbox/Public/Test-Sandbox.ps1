function Test-Sandbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    Assert-Administrator

    $DistroName           = $Config.DistroName
    $Username             = $Config.Username
    $ClaudePersistenceDir = $Config.ClaudePersistenceDir
    $Packages             = $Config.Packages

    $script:passCount = 0
    $script:failCount = 0
    $script:warnCount = 0

    function Write-CheckResult([string]$Code, [string]$Status, [string]$Name) {
        switch ($Status) {
            "PASS" {
                Write-Host "  PASS [$Code] $Name" -ForegroundColor Green
                $script:passCount++
            }
            "FAIL" {
                Write-Host "  FAIL [$Code] $Name" -ForegroundColor Red
                $script:failCount++
            }
            "WARN" {
                Write-Host "  WARN [$Code] $Name" -ForegroundColor Yellow
                $script:warnCount++
            }
        }
    }

    # Run a command in the distro and return $true/$false without exiting on failure
    function Test-InSandbox([string]$Command, [string]$User = "root") {
        wsl -d $DistroName --user $User -- bash -c $Command 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }

    # Run a command in the distro and return its output
    function Get-FromSandbox([string]$Command, [string]$User = "root") {
        $output = wsl -d $DistroName --user $User -- bash -c $Command 2>$null
        return $output
    }

    Write-Banner "Claude Sandbox Verification" @{
        Distro = $DistroName
        User   = $Username
    }

    # =====================================================================================
    # Installation Checks (I-001 through I-012)
    # =====================================================================================
    Write-Step "Installation Checks"

    # I-001: Distro registered
    $distroList = wsl -l --quiet 2>$null
    $registered = $distroList | Where-Object { $_ -replace "`0", "" | Where-Object { $_.Trim() -eq $DistroName } }
    if ($registered) {
        Write-CheckResult "I-001" "PASS" "Distro registered"
    } else {
        Write-CheckResult "I-001" "FAIL" "Distro not registered"
        Write-Host ""
        Write-Host "  Cannot continue - distro '$DistroName' not found." -ForegroundColor Red
        exit 1
    }

    # I-002: User exists
    if (Test-InSandbox "id $Username") {
        Write-CheckResult "I-002" "PASS" "User '$Username' exists"
    } else {
        Write-CheckResult "I-002" "FAIL" "User '$Username' not found"
    }

    # I-003: User in sudo group
    $groups = Get-FromSandbox "groups $Username"
    if ($groups -match '\bsudo\b') {
        Write-CheckResult "I-003" "PASS" "User in sudo group"
    } else {
        Write-CheckResult "I-003" "FAIL" "User not in sudo group"
    }

    # I-004: Required packages installed
    $pkgIndex = 0
    foreach ($pkg in $Packages) {
        $pkgIndex++
        $code = "I-004.$pkgIndex"
        if (Test-InSandbox "dpkg -s $pkg") {
            Write-CheckResult $code "PASS" "Package '$pkg' installed"
        } else {
            Write-CheckResult $code "FAIL" "Package '$pkg' not installed"
        }
    }

    # I-005: wsl.conf exists
    if (Test-InSandbox "test -f /etc/wsl.conf") {
        Write-CheckResult "I-005" "PASS" "wsl.conf exists"
    } else {
        Write-CheckResult "I-005" "FAIL" "wsl.conf missing"
    }

    # I-006: .bashrc deployed
    if (Test-InSandbox "test -f /home/$Username/.bashrc" $Username) {
        Write-CheckResult "I-006" "PASS" ".bashrc deployed"
    } else {
        Write-CheckResult "I-006" "FAIL" ".bashrc missing"
    }

    # I-007: Workflow deployed
    if (Test-InSandbox "test -f /home/$Username/.bashrc.d/workflow.sh" $Username) {
        Write-CheckResult "I-007" "PASS" "Workflow deployed"
    } else {
        Write-CheckResult "I-007" "FAIL" "Workflow missing"
    }

    # I-008: .claude persistence dir exists
    if (Test-InSandbox "test -d /home/$Username/.claude" $Username) {
        Write-CheckResult "I-008" "PASS" "Persistence directory exists"
    } else {
        Write-CheckResult "I-008" "FAIL" "Persistence directory missing"
    }

    # I-009: .claude mount in fstab
    $fstab = Get-FromSandbox "cat /etc/fstab"
    $escapedPath = [regex]::Escape($ClaudePersistenceDir)
    if ($fstab -match $escapedPath) {
        Write-CheckResult "I-009" "PASS" "Persistence mount in fstab"
    } else {
        Write-CheckResult "I-009" "FAIL" "Persistence mount not in fstab"
    }

    # I-010: .claude.json symlink exists
    if (Test-InSandbox "test -L /home/$Username/.claude.json" $Username) {
        Write-CheckResult "I-010" "PASS" ".claude.json symlink exists"
    } else {
        Write-CheckResult "I-010" "FAIL" ".claude.json symlink missing"
    }

    # I-011: Projects dir exists
    if (Test-InSandbox "test -d /home/$Username/projects" $Username) {
        Write-CheckResult "I-011" "PASS" "Projects directory exists"
    } else {
        Write-CheckResult "I-011" "FAIL" "Projects directory missing"
    }

    # I-012: Claude Code installed (warn-only)
    if (Test-InSandbox "which claude" $Username) {
        Write-CheckResult "I-012" "PASS" "Claude Code installed"
    } else {
        Write-CheckResult "I-012" "WARN" "Claude Code not installed"
    }

    # =====================================================================================
    # Security Checks (S-001 through S-011)
    # =====================================================================================
    Write-Step "Security Checks"

    # Read wsl.conf once for S-001 through S-006
    $wslConf = Get-FromSandbox "cat /etc/wsl.conf"
    $wslConfText = ($wslConf | Out-String)

    # S-001: Windows interop disabled
    $interopOk = $false
    if ($wslConfText -match '\[interop\]') {
        $interopSection = ($wslConfText -split '\[interop\]')[1]
        if ($interopSection -and $interopSection.Split('[')[0] -match 'enabled\s*=\s*false') {
            $interopOk = $true
        }
    }
    if ($interopOk) {
        Write-CheckResult "S-001" "PASS" "Windows interop disabled"
    } else {
        Write-CheckResult "S-001" "FAIL" "Windows interop not disabled"
    }

    # S-002: Windows PATH excluded
    if ($wslConfText -match 'appendWindowsPath\s*=\s*false') {
        Write-CheckResult "S-002" "PASS" "Windows PATH excluded"
    } else {
        Write-CheckResult "S-002" "FAIL" "Windows PATH not excluded"
    }

    # S-003: Automount disabled
    $automountOk = $false
    if ($wslConfText -match '\[automount\]') {
        $automountSection = ($wslConfText -split '\[automount\]')[1]
        if ($automountSection -and $automountSection.Split('[')[0] -match 'enabled\s*=\s*false') {
            $automountOk = $true
        }
    }
    if ($automountOk) {
        Write-CheckResult "S-003" "PASS" "Automount disabled"
    } else {
        Write-CheckResult "S-003" "FAIL" "Automount not disabled"
    }

    # S-004: protectBinfmt enabled
    if ($wslConfText -match 'protectBinfmt\s*=\s*true') {
        Write-CheckResult "S-004" "PASS" "protectBinfmt enabled"
    } else {
        Write-CheckResult "S-004" "FAIL" "protectBinfmt not enabled"
    }

    # S-005: systemd enabled
    if ($wslConfText -match 'systemd\s*=\s*true') {
        Write-CheckResult "S-005" "PASS" "systemd enabled"
    } else {
        Write-CheckResult "S-005" "FAIL" "systemd not enabled"
    }

    # S-006: Default user is non-root
    if ($wslConfText -match "default\s*=\s*$Username") {
        Write-CheckResult "S-006" "PASS" "Default user is '$Username'"
    } else {
        Write-CheckResult "S-006" "FAIL" "Default user is not '$Username'"
    }

    # S-007: Sudo is password-gated (no NOPASSWD)
    $sudoersCheck = Get-FromSandbox "grep -r 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null"
    if (-not $sudoersCheck) {
        Write-CheckResult "S-007" "PASS" "Sudo password-gated"
    } else {
        Write-CheckResult "S-007" "FAIL" "NOPASSWD found in sudoers"
    }

    # S-008: Sudo password feedback
    if (Test-InSandbox "test -f /etc/sudoers.d/pwfeedback") {
        Write-CheckResult "S-008" "PASS" "Sudo password feedback enabled"
    } else {
        Write-CheckResult "S-008" "WARN" "Sudo password feedback not configured"
    }

    # S-009: User namespaces enabled (for bubblewrap/sandbox mode)
    $userns = Get-FromSandbox "cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null"
    if ((-not $userns) -or ($userns.Trim() -eq "1")) {
        Write-CheckResult "S-009" "PASS" "User namespaces enabled"
    } else {
        Write-CheckResult "S-009" "FAIL" "User namespaces disabled"
    }

    # S-010: fstab mount has correct umask
    if ($fstab -match 'umask=022') {
        Write-CheckResult "S-010" "PASS" "fstab umask=022"
    } else {
        Write-CheckResult "S-010" "FAIL" "fstab umask not 022"
    }

    # S-011: fstab mount has metadata flag
    if ($fstab -match 'metadata') {
        Write-CheckResult "S-011" "PASS" "fstab metadata flag set"
    } else {
        Write-CheckResult "S-011" "FAIL" "fstab metadata flag missing"
    }

    # =====================================================================================
    # Summary
    # =====================================================================================
    Write-Host ""
    $divider = "-" * 60
    Write-Host "  $divider" -ForegroundColor DarkGray
    $summaryParts = @()
    $summaryParts += "$script:passCount passed"
    if ($script:failCount -gt 0) {
        $summaryParts += "$script:failCount failed"
    }
    if ($script:warnCount -gt 0) {
        $summaryParts += "$script:warnCount warnings"
    }
    $summary = $summaryParts -join ", "

    if ($script:failCount -eq 0) {
        Write-Host "  All checks passed: $summary" -ForegroundColor Green
    } else {
        Write-Host "  Result: $summary" -ForegroundColor Red
    }
    Write-Host "  $divider" -ForegroundColor DarkGray
    Write-Host ""

    if ($script:failCount -gt 0) {
        exit 1
    }
}
