# ADR-004: Persistence mount

**Date:** 2026-03-27
**Status:** Accepted

## Context

Claude Code stores its state - login credentials, memory, conversation history, settings, and tool permissions - in a ~/.claude directory. If this directory is inside the WSL2 distro, it is destroyed every time the distro is rebuilt. Rebuilding the distro (to apply updates or reset a compromised environment) would require re-authentication and lose all Claude memory and settings.

## Decision

Bind-mount ~/.claude from a Windows directory ($ClaudePersistenceDir) via /etc/fstab. The directory persists on the Windows host across all distro rebuilds. A symlink ~/.claude.json -> ~/.claude/.claude.json ensures Claude's top-level config file is also persisted.

## Consequences

- Claude login, memory, and settings survive distro rebuilds
- Recovery from a bad state is: rebuild distro, run installer, everything works
- The persistence directory is always mounted read-write - Claude can write to it

## Security Implications

This is the primary security trade-off in the persistence design. Claude has full read and write access to its own settings, conversation history, API credentials, and tool permission rules via the persistence mount. A compromised Claude session could:

- Read conversation history from previous sessions
- Widen its own tool permissions for future sessions by modifying settings.json
- Read the Claude API key stored in the directory

Mitigations considered and their outcomes:

- Read-only mount: rejected - Claude cannot function with a read-only ~/.claude
- Per-file ACLs: not supported by drvfs at the file level
- Separate read-only mount for credentials: not supported by Claude Code's directory structure
- Managed settings file (planned): will enforce deny rules at the application layer regardless of what settings.json contains, partially mitigating the permission-widening risk

This risk is accepted as a necessary trade-off for the persistence feature. Users should be aware that Claude can read all files in $ClaudePersistenceDir.
