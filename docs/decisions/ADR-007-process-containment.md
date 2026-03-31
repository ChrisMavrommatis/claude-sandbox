# ADR-007: Process containment on WSL2

- **Date:** 2026-03-31
- **Status:** Blocked (WSL2 kernel limitation)

## Problem

Standard Linux process containment mechanisms - AppArmor, seccomp, Landlock, SELinux -
provide per-process mandatory access control at the kernel level. None are viable on the
stock WSL2 kernel. This ADR documents why and what is used instead.

## What was evaluated

| Mechanism | What it does                                          | WSL2 feasibility |
|-----------|-------------------------------------------------------|------------------|
| AppArmor  | Per-process filesystem and network MAC via profiles   | Blocked          |
| seccomp   | Syscall allowlist/denylist per process                | Unreliable       |
| Landlock  | Unprivileged filesystem sandboxing via LSM            | Blocked          |
| SELinux   | Full MAC framework with policy database               | Blocked          |

## Why each mechanism is blocked

**AppArmor** - The stock WSL2 kernel is not compiled with AppArmor support. Forcing it
via `kernelCommandLine = apparmor=1 security=apparmor` in `.wslconfig` results in the
AppArmor service failing with `ConditionSecurity=apparmor was not met`. A custom WSL2
kernel with AppArmor compiled in is technically possible but has a critical additional
problem: AppArmor kernel state is shared across all WSL2 distros on the machine. A
profile loaded inside the Claude sandbox would affect every other distro. This makes
AppArmor unsafe to deploy in a shared-kernel environment regardless of kernel support.

**seccomp** - The WSL2 kernel has `CONFIG_SECCOMP` enabled, but direct seccomp usage
from user processes is unreliable across WSL2 kernel builds. More relevantly, applying
seccomp filters externally to Claude's process requires root and a wrapper - there is no
clean mechanism to confine an already-running process without modifying how it is
launched. Bubblewrap uses seccomp internally and handles the WSL2 limitations at
runtime - this is why Claude sandbox mode works despite the restriction.

**Landlock** - Requires `CONFIG_SECURITY_LANDLOCK` and the `landlock_create_ruleset(2)`
syscall. The stock WSL2 kernel does not enable Landlock. Attempts to use the Landlock
API return `ENOSYS` (syscall not implemented).

**SELinux** - Requires `CONFIG_SECURITY_SELINUX` and a full policy database loaded at
boot. Not compiled into the stock WSL2 kernel. Even if it were, SELinux policy authoring
for a dynamic command execution environment like Claude is impractical - profiles are
defined per binary path, which does not suit Claude's workload.

## Decision

**Do not implement AppArmor, seccomp, Landlock, or SELinux. Use bubblewrap (S-009)
as the primary process containment mechanism.**

Bubblewrap is more appropriate than any of the above for this use case - it sandboxes
at the process level at runtime with no static profile authoring, and it handles WSL2
limitations internally.

## What this means in practice

- Claude sandbox mode (`/sandbox`) uses bubblewrap for filesystem and network isolation
- No per-process kernel MAC profiles exist outside of bubblewrap
- `sandbox.failIfUnavailable` is not enforced - Claude can run bash without bubblewrap
  if sandbox mode is not active

## Equivalence table

| MAC capability                | Equivalent control in this sandbox                                 |
|-------------------------------|--------------------------------------------------------------------|
| Filesystem access per-process | Bubblewrap namespaces (S-009, Claude sandbox mode)                 |
| Network access per-process    | `allowedDomains` filtering when Claude sandbox mode active (I-013) |
| Restrict dangerous commands   | Managed deny list (S-021, I-013)                                   |
| Privilege escalation guard    | Non-root user (S-006) + password-gated sudo (S-007)                |

## Accepted risk

No kernel-level MAC enforcement exists outside Claude sandbox mode. When sandbox mode
is not active, bash commands run with the full privileges of the sandbox user and no
per-process filesystem or network restrictions apply beyond the distro boundary.

## Condition for revisiting

- **AppArmor / SELinux:** Microsoft ships kernel support AND resolves the cross-distro
  state sharing problem. Monitor: https://github.com/microsoft/WSL/issues/8709
- **Landlock:** Microsoft enables `CONFIG_SECURITY_LANDLOCK` in the stock WSL2 kernel.
- **seccomp:** A clean mechanism to wrap Claude's launch with seccomp filters emerges
  without requiring root or modifying the upstream installer.

## Controls reference

Bubblewrap: S-009.
Process containment gaps: `docs/security-posture.md` - Process Containment section.
