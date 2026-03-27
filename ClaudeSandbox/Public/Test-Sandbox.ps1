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
    # Installation Checks
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
    if (Test-InSandbox "test -f /home/$Username/.local/bin/claude" $Username) {
        Write-CheckResult "I-012" "PASS" "Claude Code installed"
    } else {
        Write-CheckResult "I-012" "WARN" "Claude Code not installed"
    }

    # I-013: Managed settings deployed
    if (Test-InSandbox "test -f /etc/claude-code/managed-settings.json") {
        Write-CheckResult "I-013" "PASS" "Managed settings deployed"
    } else {
        Write-CheckResult "I-013" "FAIL" "Managed settings missing"
    }

    # I-014: Managed policy deployed
    if (Test-InSandbox "test -f /etc/claude-code/CLAUDE.md") {
        Write-CheckResult "I-014" "PASS" "Managed policy deployed"
    } else {
        Write-CheckResult "I-014" "FAIL" "Managed policy missing"
    }

    # =====================================================================================
    # Security Checks
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

    # S-012: Project name validation rejects path traversal
    if (Test-InSandbox "source /home/$Username/.bashrc.d/workflow.sh && mount-project '../../etc' 2>/dev/null" $Username) {
        Write-CheckResult "S-012" "FAIL" "Path traversal not blocked"
    } else {
        Write-CheckResult "S-012" "PASS" "Project name validation active"
    }

    # S-013: Password is not the default 'changeme' (warn-only)
    $pwCheck = Get-FromSandbox "echo 'changeme' | su -c 'echo ok' $Username 2>/dev/null"
    if ($pwCheck -and $pwCheck.Trim() -eq "ok") {
        Write-CheckResult "S-013" "WARN" "Password is still 'changeme'"
    } else {
        Write-CheckResult "S-013" "PASS" "Password changed from default"
    }

    # S-014: GPU setting matches config
    $gpuExpected = if ($Config.GpuEnabled) { "true" } else { "false" }
    if ($wslConfText -match "enabled\s*=\s*$gpuExpected" -and $wslConfText -match '\[gpu\]') {
        Write-CheckResult "S-014" "PASS" "GPU setting matches config ($gpuExpected)"
    } else {
        Write-CheckResult "S-014" "WARN" "GPU setting in wsl.conf does not match config (expected $gpuExpected)"
    }

    # S-015: wsl.conf owned by root and not world-writable
    $wslConfPerms = Get-FromSandbox "stat -c '%U %a' /etc/wsl.conf 2>/dev/null"
    if ($wslConfPerms -and $wslConfPerms.Trim() -match '^root \d[0-5][0-5]$') {
        Write-CheckResult "S-015" "PASS" "wsl.conf permissions secure"
    } else {
        Write-CheckResult "S-015" "FAIL" "wsl.conf has wrong owner or is world-writable"
    }

    # S-016: sudoers.d/pwfeedback has correct permissions (0440)
    if (Test-InSandbox "test -f /etc/sudoers.d/pwfeedback") {
        $sudoPerms = Get-FromSandbox "stat -c '%U %a' /etc/sudoers.d/pwfeedback 2>/dev/null"
        if ($sudoPerms -and $sudoPerms.Trim() -match '^root 440$') {
            Write-CheckResult "S-016" "PASS" "pwfeedback permissions correct (0440)"
        } else {
            Write-CheckResult "S-016" "FAIL" "pwfeedback has wrong permissions (expected root 440)"
        }
    } else {
        Write-CheckResult "S-016" "WARN" "pwfeedback not present, skipping permission check"
    }

    # S-017: umask 022 enforced in .bashrc
    $umaskCheck = Get-FromSandbox "grep -q 'umask 022' /home/$Username/.bashrc 2>/dev/null && echo yes"
    if ($umaskCheck -and $umaskCheck.Trim() -eq "yes") {
        Write-CheckResult "S-017" "PASS" "umask 022 set in profile"
    } else {
        Write-CheckResult "S-017" "FAIL" "umask 022 not found in profile"
    }

    # S-019: fstab-only mounts (mountFsTab = true in wsl.conf)
    if ($wslConfText -match 'mountFsTab\s*=\s*true') {
        Write-CheckResult "S-019" "PASS" "fstab-only mounts enabled"
    } else {
        Write-CheckResult "S-019" "FAIL" "mountFsTab not set to true"
    }

    # S-020: Session timeout (only if configured)
    $sessionTimeout = if ($Config.SessionTimeout) { $Config.SessionTimeout } else { 0 }
    if ($sessionTimeout -gt 0) {
        $tmoutCheck = Get-FromSandbox "grep -q 'readonly TMOUT' /etc/profile.d/session-timeout.sh 2>/dev/null && echo yes"
        if ($tmoutCheck -and $tmoutCheck.Trim() -eq "yes") {
            Write-CheckResult "S-020" "PASS" "Session timeout configured (${sessionTimeout}s)"
        } else {
            Write-CheckResult "S-020" "FAIL" "Session timeout not properly configured"
        }
    }

    # S-018: History timestamps enabled for audit trail
    $histCheck = Get-FromSandbox "grep -q 'HISTTIMEFORMAT' /home/$Username/.bashrc 2>/dev/null && echo yes"
    if ($histCheck -and $histCheck.Trim() -eq "yes") {
        Write-CheckResult "S-018" "PASS" "History timestamps enabled"
    } else {
        Write-CheckResult "S-018" "FAIL" "HISTTIMEFORMAT not set in profile"
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
