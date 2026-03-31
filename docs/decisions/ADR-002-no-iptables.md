# ADR-002: No iptables for outbound filtering

- **Date:** 2026-03-27
- **Status:** Accepted

## Problem

Claude and code it runs have unrestricted outbound network access by default. The obvious
Linux mitigation is iptables rules inside the WSL2 distro - but WSL2 makes this
unreliable in practice.

## Why iptables doesn't work on WSL2

| Mode                              | Problem                                                                                 |
|-----------------------------------|-----------------------------------------------------------------------------------------|
| NAT mode (default)                | Virtual adapter recreated on every restart - rules don't survive reliably               |
| Mirrored networking (Win 11 22H2+) | Distro shares host interfaces directly - iptables rules affect the Windows host         |

Both modes make automated iptables rules either fragile or unsafe. UFW inherits the same
problems as it is a frontend for iptables.

## Decision

**Do not use iptables inside the distro for outbound filtering.**

Use Claude's sandbox network proxy (`allowedDomains`) for bash command filtering, and
accept that Claude's built-in tools (WebFetch) are unfiltered. Host-level controls are
the user's responsibility.

## What this means in practice

- Bash commands are domain-filtered via `allowedDomains` when Claude sandbox mode is
  active (I-013) - this is the primary mitigation
- WebFetch bypasses all sandbox controls - unfiltered, accepted gap
- Windows Firewall rules are the correct layer for host-level egress control; guidance
  is documented in `docs/safe-usage.md` but not automated from inside the distro
- The outbound filtering gap is tracked in security-posture.md (Host Isolation, No)

## Accepted risk

Bash commands are unfiltered when Claude sandbox mode is not active. WebFetch is always
unfiltered. A compromised dependency or tool can reach arbitrary internet hosts unless
the user configures host-level Windows Firewall rules independently.

## Controls reference

Sandbox network proxy: I-013.
Host Isolation gap: `docs/security-posture.md` - Outbound network filtering row.
Windows Firewall guidance: `docs/safe-usage.md`.
