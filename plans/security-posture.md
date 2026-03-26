# Security Posture — Summary

> For full details see [security-posture-details.md](security-posture-details.md)

---

## What's Covered

| Domain | Covered |
|--------|---------|
| Host isolation (WSL2 boundary, no Windows interop, no Windows PATH) | Yes |
| Drive access (no auto-mounts, fstab-only, on-demand project mounts) | Yes |
| Mount access control (read-only / read-write modes, ownership, umask) | Yes |
| Non-root default user with password-gated sudo | Yes |
| Process containment (systemd, bubblewrap namespaces) | Yes |
| Deployment integrity (token replacement, LF/UTF-8 enforcement) | Yes |
| Claude permission modes (plan / acceptEdits / full) | Yes |
| Per-project policies via CLAUDE.md | Yes |
| Permanent tool deny lists via settings.json | Yes |
| Worktree isolation for risky changes | Yes |
| Git audit trail for all Claude changes | Yes |
| Admin elevation required for all installer scripts | Yes |
| Safe uninstall (confirmation prompt, persistence preserved) | Yes |
| Temp file cleanup after installation | Yes |

---

## What's Missing

| Gap | Severity |
|-----|----------|
| No outbound network filtering | HIGH |
| No resource limits (CPU / memory / disk) | MEDIUM |
| No audit logging (commands, mounts, processes) | MEDIUM |
| No input validation on project names (path traversal risk) | MEDIUM |
| No image digest pinning (floating `debian:bookworm-slim` tag) | MEDIUM |
| No update / patch mechanism for installed packages | MEDIUM |
| Claude installer uses curl-pipe-bash with no checksum | MEDIUM |
| Plaintext password in sandbox-config.ps1 | LOW–MEDIUM |
| No session timeout (idle shells stay open) | LOW |
| GPU passthrough enabled by default when not needed | LOW |
| No secret management guidance (.env, API keys) | LOW |
| No backup strategy for persistence mount | LOW |
