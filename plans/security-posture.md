# Security Posture - Summary

> For full details see [security-posture-details.md](security-posture-details.md)

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

| Gap | Severity | Notes |
|-----|----------|-------|
| No outbound network filtering | HIGH | No iptables/nftables or proxy |
| No resource limits (CPU / memory / disk) | MEDIUM | No .wslconfig template |
| No audit logging (commands, mounts, processes) | MEDIUM | No auditd/syslog |
| No image digest pinning (floating tag) | MEDIUM | Still uses `debian:bookworm-slim` |
| Claude installer uses curl-pipe-bash with no checksum | MEDIUM | No offline alternative available |
| No session timeout (idle shells stay open) | LOW | No TMOUT in profiles |
| No secret management guidance (.env, API keys) | LOW | Nothing in docs |
| No backup strategy for persistence mount | LOW | Nothing in docs |

---

## Previously Missing, Now Fixed

| Gap | Fixed by | Check |
|-----|----------|-------|
| No input validation on project names | `_validate_project_name()` in workflow script | S-012 |
| Plaintext password in config with no warning | Install-Sandbox prompts on default password | S-013 |
| GPU passthrough enabled by default | `$GpuEnabled` config toggle, default `$false` | S-014 |
| No update / patch mechanism | `Update-ClaudeSandbox.ps1` / `Update-Sandbox` | - |
