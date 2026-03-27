# ADR-001: WSL2 over full VM

**Date:** 2026-03-27
**Status:** Accepted

## Context

Claude Sandbox needs an isolated Linux environment on a Windows developer machine. The options considered were WSL2 and a full hypervisor VM (Hyper-V, VirtualBox, or VMware). The environment must support Claude Code's bubblewrap sandbox mode, mount Windows project folders on demand, and start quickly enough for daily use.

## Decision

Use WSL2. The Hyper-V-backed VM boundary provides meaningful isolation for the primary threat (containment of Claude's actions), while drvfs mounts, fast startup, and native Windows Terminal integration make it practical for daily development.

## Consequences

- Install is a one-command PowerShell script; no VM image management
- Projects mount instantly via drvfs with no syncing
- WSL2 starts in seconds vs minutes for a full VM
- Windows interop, automount, and Windows PATH must be explicitly disabled (done - S-001, S-002, S-003) because they are enabled by default and would break the isolation boundary

## Security Implications

WSL2 is not as isolated as a full VM. A full hypervisor VM with no shared clipboard, no shared filesystem, and no guest additions would provide stronger containment. The trade-off was made in favour of usability for daily developer use. A kernel-level exploit in WSL2 could theoretically break containment to the Windows host. This risk is accepted - the primary threat model is Claude acting outside its intended scope, not a kernel exploit. If the threat model changes (e.g. running untrusted third-party code at scale), a full VM should be reconsidered.
