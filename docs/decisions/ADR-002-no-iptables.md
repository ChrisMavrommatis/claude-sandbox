# ADR-002: No iptables

**Date:** 2026-03-27
**Status:** Accepted

## Context

A key goal is preventing Claude or code it runs from exfiltrating data over the network. The obvious Linux approach is iptables rules inside the WSL2 distro.

## Decision

Do not rely on iptables inside WSL2 for outbound filtering. Instead:
- Rely on Claude's sandbox network proxy (allowedDomains) for bash commands (planned - not yet deployed)
- Accept that Claude's built-in tools (WebFetch) are unfiltered
- Document host-level options (Windows Firewall, host-side proxy) in safe-usage.md but do not automate them from inside the sandbox

## Consequences

- No outbound network filtering is active today for bash commands (gap tracked in security-posture.md as HIGH / Not Supported)
- When sandbox network proxy is deployed, bash commands will be domain-filtered
- WebFetch remains unfiltered - this is an accepted residual risk

## Security Implications

iptables inside WSL2 has two fundamental problems:

1. In NAT mode (default): the virtual network adapter is recreated on every WSL restart. iptables rules can be restored via a systemd service, but they bind to an adapter that may not exist in the same state after restart, making them fragile in practice.

2. In mirrored networking mode (Windows 11 22H2+): WSL2 shares the host's physical network interfaces directly. iptables rules inside the distro affect host-level interfaces, making automation dangerous and behaviour unpredictable. Multiple open issues in the WSL2 GitHub repository document interface disappearance and instability in mirrored mode.

The maintenance burden and fragility outweigh the security benefit for a local developer sandbox. Host-level Windows Firewall rules are the correct layer for network egress control, but their management is outside the scope of this project and must be handled by the user.
