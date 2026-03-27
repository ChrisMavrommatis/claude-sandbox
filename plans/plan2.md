## Task: Portfolio improvements and lower-priority hardening.
## Work through in order. After each task state what changed.

---

### TASK 1 — README badges

File: README.md

Add a badges line immediately after the H1 title, before "A one-command setup":

![Security Checks](https://img.shields.io/badge/security_checks-21_passing-brightgreen)
![Verified](https://img.shields.io/badge/posture-verified-blue)
![WSL2](https://img.shields.io/badge/platform-WSL2-0078D4?logo=windows)
![PowerShell](https://img.shields.io/badge/shell-PowerShell-5391FE?logo=powershell)

Note: the "21 passing" count should match the actual number of check codes
in the CLAUDE.md check table at the time this runs. Count them and use the
correct number. The badge is static -- update it manually when new checks
are added.

---

### TASK 2 — CHANGELOG.md

Create CHANGELOG.md at the project root.

Format: Keep a Changelog (keepachangelog.com). Use these exact headings.

```markdown
# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.1.0] - 2026-03-27

### Security
- Deployed managed settings file to /etc/claude-code/managed-settings.json
  enforcing sandbox mode, failIfUnavailable, and command deny rules (I-013)
- Deployed managed policy CLAUDE.md to /etc/claude-code/CLAUDE.md (I-014)
- Added PreToolUse credential guard hook blocking reads of .env, *.pem,
  and credential file patterns (I-015)
- Configured sandbox network proxy with allowedDomains for bash commands
- Fixed session timeout to use readonly TMOUT via /etc/profile.d/ (S-020)
- Added image digest pinning WARN check (S-022)
- Added managed settings deny rule verification check (S-021)
- Fixed S-013 password check to use Python crypt instead of su pipe
- Added Enforcement column to security-posture.md tables
- Documented AppArmor as blocked on WSL2 kernel

### Added
- docs/threat-model.md - full STRIDE threat model with accepted risks
- docs/about.md - plain-English purpose and limitations document
- docs/safe-usage.md - user guide for safe Claude operation
- docs/decisions/ - Architecture Decision Records (ADR-001 through ADR-005)
- SECURITY.md - security posture summary and reporting guidance
- CHANGELOG.md - this file

### Changed
- Tightened doc sync rule in CLAUDE.md to prevent unsupervised posture edits
- Hardened CLAUDE.md doc sync rule: security-posture files only updated
  when explicitly implementing a security control

## [1.0.0] - 2026-03-26

### Added
- Initial release: one-command WSL2 Debian sandbox for Claude Code
- Install, Uninstall, Update, Verify PowerShell scripts
- Profile and workflow system (default + pretty profiles)
- Project mount/unmount with RO/RW control and path traversal validation
- Persistence mount for Claude state across distro rebuilds
- Windows Terminal profile integration
- 21 verification check codes (I-001 through I-015, S-001 through S-022)
```

---

### TASK 3 — GitHub Actions workflow: PowerShell syntax validation

Create .github/workflows/validate.yml

```yaml
name: Validate

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  powershell-lint:
    name: PowerShell Syntax Check
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check PowerShell syntax
        shell: pwsh
        run: |
          $errors = @()
          Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
              $tokens = $null
              $parseErrors = $null
              [System.Management.Automation.Language.Parser]::ParseFile(
                  $_.FullName, [ref]$tokens, [ref]$parseErrors
              ) | Out-Null
              if ($parseErrors.Count -gt 0) {
                  $parseErrors | ForEach-Object {
                      $errors += "$($_.Extent.File): $($_.Message)"
                  }
              }
          }
          if ($errors.Count -gt 0) {
              $errors | ForEach-Object { Write-Host "ERROR: $_" -ForegroundColor Red }
              exit 1
          }
          Write-Host "All PowerShell files passed syntax check." -ForegroundColor Green

      - name: Check module manifest
        shell: pwsh
        run: |
          Test-ModuleManifest ClaudeSandbox/ClaudeSandbox.psd1
```

---

### TASK 4 — Resource limits template (opt-in)

Create ClaudeSandbox/Assets/.wslconfig.template

Content:

```ini
# WSL2 resource limits template
# Copy to %USERPROFILE%\.wslconfig to apply.
# WARNING: This file affects ALL WSL2 distros on this machine, not just
# Claude Sandbox. Review carefully before deploying.
# Uncomment and adjust values as needed.

[wsl2]
# memory=4GB          # Max memory for all WSL2 distros combined
# processors=2        # Max CPU cores available to WSL2
# swap=2GB            # Swap file size (0 to disable)
# swapFile=C:\\Temp\\wsl-swap.vhdx   # Custom swap file location
```

Also add a note in plans/security-posture-details.md under "Resource limits":
"A `.wslconfig.template` is provided in ClaudeSandbox/Assets/. Copy it to
%USERPROFILE%\\.wslconfig and uncomment values to apply limits. Not deployed
automatically because it affects all WSL2 distros on the machine."

Do not change the Status in security-posture.md -- it remains Not Supported
because deployment is manual, not automatic.

---

### TASK 5 — Document ConfigChange hooks in posture-details

File: plans/security-posture-details.md

Find the existing "ConfigChange hooks" section and update the Implementation
approach to include:

"Note: ConfigChange hooks are low priority for single-user local development
but become HIGH priority if the sandbox is used in a shared or team environment
where multiple users have access to the distro. Revisit this when the sandbox
is distributed beyond a single developer."

No code changes needed for this task.

---

### FINAL CHECKS

1. Count the actual check codes in CLAUDE.md and verify the badge number
   in README.md matches
2. Verify CHANGELOG.md version numbers and dates are consistent
3. Verify .github/workflows/validate.yml is valid YAML
4. Verify .wslconfig.template exists in ClaudeSandbox/Assets/
5. List every file created or modified with a one-line summary.