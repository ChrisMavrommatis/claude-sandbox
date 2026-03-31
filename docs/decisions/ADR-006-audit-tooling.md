# ADR-006: Audit tooling on WSL2

- **Date:** 2026-03-31
- **Status:** Blocked (WSL2 kernel limitation)

## Problem

The sandbox has no system-level audit trail. Bash history and git history cover most
developer workload scenarios, but they do not capture process spawning, mount events,
network connections, or file opens at the kernel level.

## What was evaluated

| Tool    | What it does                                      | WSL2 feasibility |
|---------|---------------------------------------------------|------------------|
| auditd  | Kernel audit daemon - syscall and file event logs | Blocked          |
| Falco   | eBPF runtime anomaly detection                    | Blocked          |
| osquery | SQL interface to OS state and process events      | Partial          |
| AIDE    | File integrity monitoring via checksums           | Viable           |
| Lynis   | CIS-aligned security audit scanner                | Viable           |

## Why the blocked tools are blocked

**auditd** - Setting the audit daemon pid requires `CAP_AUDIT_CONTROL`. The WSL2 kernel
returns `EPERM` for this operation regardless of user privileges. This is a kernel
restriction, not a configuration issue. No workaround exists without a custom kernel.

**Falco** - Requires either a loadable kernel module (`falco.ko`) or an eBPF probe
compiled against the running kernel. The WSL2 stock kernel does not support `modprobe`
and does not expose the BTF debug data Falco's BPF probe requires. Falco's own
documentation lists WSL2 as unsupported.

**osquery** - Core informational tables work, but the security-relevant tables
(`process_events`, `socket_events`, `file_events`) depend on the Linux Audit framework,
which is blocked by the same auditd restriction above. Viable for informational queries
only - not for security monitoring.

## Why the viable tools are not implemented

**AIDE** - The distro is ephemeral and rebuildable on demand. All Claude file changes
are tracked via git. AIDE is designed for long-lived production servers where the OS
install is not in version control. Maintaining an AIDE database across distro rebuilds
adds overhead with no security benefit over git history.

**Lynis** - Viable and worth pursuing as an optional user-invocable audit step. Low
effort, no install-time cost (user opts in), and provides an independent second opinion
on hardening state. Not a daemon - runs once and produces a report.

## Decision

**Do not implement kernel-level audit tooling. Accept bash history and git history
as the audit trail for the current threat model.**

Lynis is recommended as an optional audit step - not a sandbox-enforced control.

## What this means in practice

- Bash history with timestamps (S-018) is the primary command audit trail
- Git history covers all Claude changes to project files
- No process spawn, network connection, or file open events are captured at kernel level
- Suitable for single-user developer workload; not for compliance-grade audit requirements
- To run Lynis manually: `sudo apt-get install lynis && sudo lynis audit system`

## Accepted risk

A sufficiently motivated or compromised process can clear bash history. No tamper-evident
audit trail exists. This is accepted for the current threat model - containment of Claude's
actions, not forensic investigation after the fact.

If the sandbox evolves into a shared or multi-user environment, or if compliance-grade
audit is required, a non-WSL2 deployment target should be evaluated.

## Condition for revisiting

Microsoft ships `CAP_AUDIT_CONTROL` support and eBPF BTF data in the stock WSL2 kernel.
Monitor: https://github.com/microsoft/WSL/issues for audit and eBPF support.

## Controls reference

History timestamps: S-018.
Audit gap: `docs/security-posture.md` - Audit & Logging, System audit logging row.
