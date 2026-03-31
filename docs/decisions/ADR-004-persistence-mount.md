# ADR-004: Persistence mount

- **Date:** 2026-03-27
- **Status:** Accepted

## Problem

Claude Code stores login credentials, memory, conversation history, and settings in
`~/.claude`. If this lives inside the WSL2 distro, everything is lost on every rebuild.
Rebuilds are the primary recovery mechanism - losing state on recovery defeats the point.

## Decision

**Bind-mount `~/.claude` from a Windows directory (`$ClaudePersistenceDir`) via
`/etc/fstab`. The directory lives on the Windows host and survives all distro rebuilds.**

A symlink `~/.claude.json` -> `~/.claude/.claude.json` ensures Claude's top-level config
is also persisted.

## What this means in practice

- Claude login, memory, and settings survive distro rebuilds
- Recovery from a bad state is: rebuild distro, run installer, everything works
- The mount is always read-write - Claude can write to it
- Verified by I-008, I-009, I-010

## Accepted risk

The persistence mount is the primary security trade-off in this design. Claude has full
read and write access to its own credentials, history, and permission rules at all times.
A compromised session could:

- Read conversation history and API credentials from previous sessions
- Widen its own tool permissions for future sessions by modifying `settings.json`

Mitigations considered:

| Approach                                 | Outcome                                                                         |
|------------------------------------------|---------------------------------------------------------------------------------|
| Read-only mount                          | Rejected - Claude cannot function with a read-only `~/.claude`                  |
| Per-file ACLs                            | Not supported by drvfs                                                          |
| Separate read-only mount for credentials | Not supported by Claude Code's directory structure                              |
| Managed settings (I-013)                 | Enforces deny rules at runtime regardless of settings.json - partial mitigation |

Users should not store secrets in `$ClaudePersistenceDir` beyond what Claude Code
places there itself.

## Controls reference

Persistence mount checks: I-008, I-009, I-010, S-010, S-011.
Full controls matrix: [docs/security-posture.md](../security-posture.md).
