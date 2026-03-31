# ADR-001: WSL2 over full VM

- **Date:** 2026-03-27
- **Status:** Accepted

## Problem

Claude Sandbox needs an isolated Linux environment on a Windows developer machine that
starts fast, mounts Windows project folders on demand, and supports Claude Code's
bubblewrap sandbox mode - without becoming a maintenance burden.

## Options considered

| Option    | Isolation | Startup | Mount friction | Maintenance |
|-----------|-----------|---------|----------------|-------------|
| WSL2      | Medium    | Seconds | None (drvfs)   | Low         |
| Full VM   | High      | Minutes | Shared folders | High        |

## Decision

**Use WSL2.**

The Hyper-V-backed boundary is sufficient for the primary threat - Claude acting outside
its intended scope. The usability difference is significant enough for daily dev work
that a full VM is not justified.

## What this means in practice

- Install is a single PowerShell script; no VM image management
- Projects mount instantly via drvfs with no syncing overhead
- WSL2 starts in seconds; native Windows Terminal integration works out of the box
- Windows interop, automount, and Windows PATH are disabled explicitly (S-001, S-002,
  S-003) - they are enabled by default and would break the isolation boundary

## Accepted risk

WSL2 is not a full VM. A kernel-level exploit could theoretically break containment to
the Windows host. This is accepted because the threat model is Claude making mistakes or
acting outside scope - not a kernel exploit.

If the threat model changes - for example, running untrusted third-party code at scale -
a full VM should be reconsidered.

## Controls reference

Host Isolation checks in `Test-Sandbox.ps1`: S-001, S-002, S-003, S-004.
Full controls matrix: [docs/security-posture.md](../security-posture.md).
