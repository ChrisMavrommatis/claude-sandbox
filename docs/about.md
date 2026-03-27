# Purpose

## What It Is

Claude Sandbox is a pre-configured WSL2 Debian environment for running Claude Code in isolation from the Windows host. The installer automates distro creation, security hardening, persistence setup, and project mounting in a single command.

## The Problem It Solves

When Claude Code runs directly on a developer's machine, it has access to the entire filesystem, the Windows PATH, and the network. For personal projects this may be acceptable. For professional work - client code, projects with credentials, unattended runs - this is a meaningful risk. Claude Sandbox narrows what Claude can reach and limits the blast radius if something goes wrong.

## Who It Is For

- Developers who run Claude Code on client or commercially sensitive code
- Developers who run Claude unattended (Claude working while the developer does something else)
- Developers whose projects contain API keys, connection strings, or .env files
- Teams who want a consistent, auditable Claude Code environment
- Developers who want to recover quickly if Claude makes a mistake (git audit trail, isolated environment that can be rebuilt in one command)

## What It Does Not Do

- Does not prevent Claude from reading files it has access to within the sandbox. If a project with credentials is mounted read-write, Claude can read those credentials.
- Does not filter Claude's own built-in network tools. WebFetch is not sandboxed.
- Does not guarantee Claude cannot make mistakes - it limits the blast radius.
- Does not replace reviewing Claude's output before committing it.
- Is not a substitute for secrets management. Do not store production credentials in project directories that will be mounted into the sandbox.

## Security Posture

### Design Principles

- **Defense-in-depth**: multiple independent layers so no single misconfiguration exposes everything
- **Least privilege**: non-root default user, password-gated sudo, explicit RO/RW mount modes per project
- **Honest gap documentation**: known limitations are listed openly, not hidden (see Known Limitations below)
- **Verifiable posture**: every control is linked to a Test-Sandbox check code (e.g. S-001, S-007) so the security posture can be verified after any change
- **Minimal blast radius**: Windows interop disabled, automount disabled, Windows PATH excluded - Claude cannot reach the host filesystem except through explicit mounts

### Controls Summary

| Category            | Key Controls                                                                                                         | Status                       |
| ------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| Host Isolation      | WSL2 Hyper-V boundary; interop disabled (S-001); automount disabled (S-003); Windows PATH excluded (S-002)           | Supported                    |
| Filesystem          | Mount-on-demand (fstab-only, S-019); explicit RO/RW per project; path traversal validation (S-012)                   | Supported                    |
| Access Control      | Non-root default user (S-006); password-gated sudo (S-007); umask enforcement (S-017)                                | Supported                    |
| Process Containment | systemd as PID 1 (S-005); bubblewrap for Claude sandbox mode (S-009)                                                | Supported                    |
| Application Layer   | Command blocklist; tool deny lists; per-project CLAUDE.md policies; worktree isolation                               | Partial - see posture matrix |
| Audit & Logging     | Timestamped bash history (S-018); git audit trail on projects                                                        | Partial - no kernel audit    |

Full controls matrix with check codes: [plans/security-posture.md](../plans/security-posture.md)

### Known Limitations

- No outbound network filtering at the host level (WSL2 NAT architecture constraint; see [ADR-002](decisions/ADR-002-no-iptables.md) when available)
- Sandbox network proxy for bash commands not yet configured - bash has unrestricted outbound access until deployed
- Claude's built-in tools (WebFetch) are not filtered by any sandbox control
- Claude Code installed via curl-pipe-bash with no checksum verification
- Container image not pinned to digest by default - floating tag pulls latest
- Claude Code self-updates automatically; no version pinning is available
- Claude has full read access to the persistence mount by design - any credentials stored there are accessible to Claude across all sessions

### More Information

- Threat model: [threat-model.md](threat-model.md)
- Vulnerability reporting: [SECURITY.md](../SECURITY.md)
