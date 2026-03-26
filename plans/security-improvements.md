# Security Improvements - Implementation Plan

> Current state: [security-posture.md](security-posture.md)
> Full details: [security-posture-details.md](security-posture-details.md)

---

## Tier 1 - Quick wins (low effort, real impact)

### A. File permission checks in Test-Sandbox

Add two new verification checks:
- **S-015**: `/etc/wsl.conf` is owned by root and not world-writable
- **S-016**: `/etc/sudoers.d/pwfeedback` has correct permissions (0440)

Files: `ClaudeSandbox/Public/Test-Sandbox.ps1`

### B. Enforce umask in profiles

Add `umask 022` to both bashrc profiles to prevent users from accidentally making files world-writable.
- **S-017**: Verify umask is set in deployed .bashrc

Files: `ClaudeSandbox/Assets/profiles/default.sh`, `ClaudeSandbox/Assets/profiles/pretty.sh`, `ClaudeSandbox/Public/Test-Sandbox.ps1`

### C. Configurable session timeout (TMOUT)

Add `$SessionTimeout = 0` to `sandbox-config.ps1` (0 = disabled, 900 = 15 minutes). Add `__SessionTimeout__` token to profiles, replaced at deploy time. Only set TMOUT if value > 0.

Closes gap: "No session timeout"

Files: `sandbox-config.ps1`, `ClaudeSandbox/Assets/profiles/default.sh`, `ClaudeSandbox/Assets/profiles/pretty.sh`, `ClaudeSandbox/Public/Install-Sandbox.ps1`, `ClaudeSandbox/Public/Set-SandboxProfile.ps1`, all thin wrappers

### D. Image digest pinning

Change `$DistroImage` default in `sandbox-config.ps1` to `debian:bookworm-slim@sha256:<hash>`. Add a comment explaining how to update the digest when upgrading.

Closes gap: "No image digest pinning"

Files: `sandbox-config.ps1`

---

## Tier 2 - Medium effort, meaningful impact

### E. Resource limits via .wslconfig template

Ship a `.wslconfig.template` in `ClaudeSandbox/Assets/` with default `memory=4GB`, `processors=2`, `swap=2GB`. Add config variables and deploy to the Windows user profile during install.

Closes gap: "No resource limits"

Files: `ClaudeSandbox/Assets/.wslconfig.template`, `sandbox-config.ps1`, `ClaudeSandbox/Public/Install-Sandbox.ps1`

### F. Safer password handling during install

Use stdin piping instead of command-line argument for `chpasswd`. Write password to a temp file in distro, pipe it, then shred the file. Prevents password from appearing in process list.

Files: `ClaudeSandbox/Public/Install-Sandbox.ps1`

### G. Secret management guidance

Add a section to `docs/security.md` covering: where not to put secrets, .env file handling, recommending environment variables over files, suggesting `pass` or `age` for secret storage.

Closes gap: "No secret management guidance"

Files: `docs/security.md`

### H. Backup guidance

Add a section to `docs/security.md` covering: what's in the persistence directory, recommended backup frequency, robocopy example command, recovery procedure.

Closes gap: "No backup strategy"

Files: `docs/security.md`

---

## Tier 3 - Higher effort, defense-in-depth

### I. Basic audit logging

Enable bash history with timestamps in profiles (`HISTTIMEFORMAT='%F %T '`). Add mount/unmount logging to a file in the persistence directory. Not full auditd but provides a basic command trail.

Partially closes gap: "No audit logging"

Files: `ClaudeSandbox/Assets/profiles/default.sh`, `ClaudeSandbox/Assets/profiles/pretty.sh`, `ClaudeSandbox/Assets/workflows/default.sh`

### J. Symlink protection on project mounts

Add `-o nosymfollow` to drvfs mount options if supported. Or validate that the resolved project directory doesn't escape `$PROJECTS_HOME` after mount.

Files: `ClaudeSandbox/Assets/workflows/default.sh`

---

## Not planned

| Item | Reason |
|------|--------|
| Outbound network filtering | High complexity, WSL2 networking quirks. Better addressed at Windows host level (firewall, proxy). |
| Claude Code version pinning | External tool managed by Anthropic. No practical mechanism to pin. |
| PAM lockout on failed sudo | Risk of locking yourself out of the sandbox outweighs the benefit for a local dev environment. |

---

## Implementation order

Recommended sequence if implementing all tiers:

1. **Tier 1** (A, B, C, D) - closes 2 gaps, adds 3 checks, addresses 2 undocumented risks
2. **Tier 2 docs** (G, H) - closes 2 gaps with zero code changes
3. **Tier 2 code** (E, F) - closes 1 gap, fixes 1 undocumented risk
4. **Tier 3** (I, J) - partially closes 1 gap, fixes 1 undocumented risk

After all tiers: 5 gaps closed (down from 8), 3 remaining (network filtering, curl-pipe-bash, audit logging partial).
