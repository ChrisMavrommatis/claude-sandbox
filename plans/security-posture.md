# Security Posture - Summary

> For full details see [security-posture-details.md](security-posture-details.md)
> For planned improvements see [security-improvements.md](security-improvements.md)

---

## What's Covered

| Domain | Covered | Verified |
|--------|---------|----------|
| Host isolation (WSL2 boundary, no Windows interop, no Windows PATH) | Yes | S-001, S-002 |
| Drive access (no auto-mounts, fstab-only, on-demand project mounts) | Yes | S-003 |
| Mount access control (read-only / read-write modes, ownership, umask) | Yes | S-010, S-011 |
| Non-root default user with password-gated sudo | Yes | S-006, S-007 |
| Process containment (systemd, bubblewrap namespaces) | Yes | S-005, S-009 |
| Binary format protection (protectBinfmt) | Yes | S-004 |
| Deployment integrity (token replacement, LF/UTF-8 enforcement) | Yes | - |
| Project name validation (path traversal blocked) | Yes | S-012 |
| Default password detection (warns on install, checked by verify) | Yes | S-013 |
| GPU passthrough configurable (default: off) | Yes | S-014 |
| Sudo password feedback | Yes | S-008 |
| Claude permission modes (plan / acceptEdits / full) | Yes | - |
| Per-project policies via CLAUDE.md | Yes | - |
| Permanent tool deny lists via settings.json | Yes | - |
| Worktree isolation for risky changes | Yes | - |
| Git audit trail for all Claude changes | Yes | - |
| Admin elevation required for all installer scripts | Yes | - |
| Safe uninstall (confirmation prompt, persistence preserved) | Yes | - |
| Temp file cleanup after installation | Yes | - |
| Update mechanism (apt upgrade + profile re-deploy) | Yes | - |
| Post-install verification (26 automated checks) | Yes | I-001..I-012, S-001..S-014 |

---

## What's Missing

| Gap | Severity | Planned fix |
|-----|----------|-------------|
| No outbound network filtering | HIGH | Not planned - best addressed at Windows host level |
| No resource limits (CPU / memory / disk) | MEDIUM | Tier 2: .wslconfig template |
| No audit logging (commands, mounts, processes) | MEDIUM | Tier 3: bash history timestamps + mount logging |
| No image digest pinning (floating tag) | MEDIUM | Tier 1: pin `@sha256:` in sandbox-config.ps1 |
| Claude installer uses curl-pipe-bash with no checksum | MEDIUM | No fix available - waiting on offline package from Anthropic |
| No session timeout (idle shells stay open) | LOW | Tier 1: configurable `$SessionTimeout` / TMOUT |
| No secret management guidance (.env, API keys) | LOW | Tier 2: section in docs/security.md |
| No backup strategy for persistence mount | LOW | Tier 2: section in docs/security.md |

### Undocumented risks (found during review)

| Risk | Severity | Planned fix |
|------|----------|-------------|
| File permissions not verified (wsl.conf, sudoers could be writable) | MEDIUM | Tier 1: S-015, S-016 checks |
| No umask enforcement in shell profiles | LOW | Tier 1: `umask 022` in profiles, S-017 check |
| Symlink escape from project mounts | LOW-MEDIUM | Tier 3: `nosymfollow` mount option or validation |
| Password visible in process list during install | LOW | Tier 2: pipe to chpasswd via stdin |
| No failed sudo attempt limiting | LOW | Not planned - risk of lockout outweighs benefit |
| Claude Code auto-updates outside sandbox control | LOW | Not fixable - external tool |

---

## Previously Missing, Now Fixed

| Gap | Fixed by | Check |
|-----|----------|-------|
| No input validation on project names | `_validate_project_name()` in workflow script | S-012 |
| Plaintext password in config with no warning | Install-Sandbox prompts on default password | S-013 |
| GPU passthrough enabled by default | `$GpuEnabled` config toggle, default `$false` | S-014 |
| No update / patch mechanism | `Update-ClaudeSandbox.ps1` / `Update-Sandbox` | - |
