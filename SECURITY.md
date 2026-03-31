# Claude Sandbox - Security Overview

Claude Sandbox is a pre-configured WSL2 Debian environment that isolates Claude Code from the Windows host.
It is designed to reduce the blast radius if Claude acts outside its intended scope - particularly for professional work, unattended sessions, and projects containing credentials.

## Design Principles

- **Defense-in-depth**: multiple independent layers so no single misconfiguration exposes everything
- **Least privilege**: non-root default user, password-gated sudo, explicit RO/RW mount modes per project
- **Minimal blast radius**: Windows interop, automount, and Windows PATH are all disabled by default
- **Verifiable posture**: every control maps to a `Test-Sandbox` check code (e.g. `S-001`) so state can be confirmed after any change
- **Honest gaps**: known limitations are documented openly, not hidden

## Security Controls

### Host Isolation

Claude cannot reach the host filesystem except through explicitly configured project mounts.

| Check | Control                  |
|-------|--------------------------|
| S-001 | Windows interop disabled |
| S-002 | Windows PATH excluded    |
| S-003 | Automount disabled       |

### Filesystem

| Check | Control                                    |
|-------|--------------------------------------------|
| S-012 | Path traversal validation on project names |
| S-019 | fstab-only mounts (mount-on-demand)        |
| -     | Explicit RO/RW mode declared per project   |

### User & Privilege

| Check | Control                              |
|-------|--------------------------------------|
| S-006 | Non-root default user                |
| S-007 | Password-gated sudo (no NOPASSWD)    |
| S-017 | umask 022 enforced in profile        |

### Process Containment

| Check | Control                                          |
|-------|--------------------------------------------------|
| S-005 | systemd as PID 1                                 |
| S-009 | bubblewrap user namespaces (Claude sandbox mode) |

### Application Layer

| Check | Control                                                               |
|-------|-----------------------------------------------------------------------|
| I-013 | Managed settings deployed (`/etc/claude-code/managed-settings.json`) |
| I-014 | Managed policy deployed (`/etc/claude-code/CLAUDE.md`)               |
| I-015 | PreToolUse credential guard hook                                      |
| S-021 | Catastrophic commands denied (`rm -rf`, `dd`, `mkfs`) in all tiers   |
| -     | Network and package install blocked in restrictive/maximum tiers      |

### Audit & Logging

| Check | Control                                        |
|-------|------------------------------------------------|
| S-018 | Timestamped bash history                       |
| -     | Git audit trail on project directories         |

> **Gap:** No kernel-level audit (auditd). Not currently implemented.

### Deployment Integrity

| Check | Control                                             |
|-------|-----------------------------------------------------|
| S-022 | Container image digest pinning (warn if not pinned) |
| -     | Managed hook and policy files verified post-deploy  |

> **Gap:** Claude Code installed via curl-pipe-bash with no checksum verification. Container image not digest-pinned by default.

### Admin Operations

| Check | Control                                                 |
|-------|---------------------------------------------------------|
| -     | All installer scripts require Administrator elevation   |
| -     | `Test-Sandbox.ps1` verifies posture after every install |
| -     | Uninstall never deletes the persistence directory       |

## Known Limitations

- **No outbound network filtering at the host level**: WSL2 NAT makes this impractical (see [ADR-002](docs/decisions/ADR-002-no-iptables.md)).
The sandbox network proxy restricts bash commands to an approved domain list when Claude sandbox mode is active, but Claude sandbox mode is user-enabled, not enforced.
- **WebFetch is unfiltered**: Claude's built-in web tool bypasses all distro controls
- **No install integrity**: Claude Code is installed via curl-pipe-bash with no checksum verification (see [ADR-005](docs/decisions/ADR-005-curl-pipe-bash.md))
- **No version pinning**: Claude Code self-updates automatically; container image is not digest-pinned by default
- **Persistence mount is fully readable**: Credentials stored in `~/.claude` are accessible to Claude across all sessions by design

## Further Reading

- [Threat model](docs/threat-model.md)
- [Full controls matrix](docs/security-posture.md)
- [Architecture decisions](docs/decisions/)

## Reporting Security Issues

Open a [private GitHub security advisory](../../security/advisories/new) rather than a public issue, so details are not disclosed before a fix is available.

For vulnerabilities in Claude Code itself, report to Anthropic via [HackerOne](https://hackerone.com/anthropic-vdp).