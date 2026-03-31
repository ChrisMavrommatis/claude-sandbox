# ADR-005: curl-pipe-bash for Claude Code install

- **Date:** 2026-03-27
- **Status:** Accepted

## Problem

Claude Code has no package manager distribution. The only official installer is:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

This executes a remote script immediately with no checksum verification, no signature
check, and no opportunity to inspect before it runs.

## Decision

**Use the official Anthropic installer as-is. No viable alternative exists.**

## What this means in practice

- Install is straightforward and tracks Anthropic's official distribution
- No version pinning - installs whatever is current at install time
- The installer runs inside the WSL2 distro, not on the Windows host - blast radius
  is contained
- Users who want to inspect the script can download it to a temp file first, but there
  is no known-good hash to verify against so this provides limited security value

## Accepted risk

HTTPS protects against network-level interception but not against:

- Server-side compromise of claude.ai
- CDN poisoning
- Time-of-check / time-of-use substitution between download and execution

This is accepted because:

1. No alternative distribution exists from Anthropic
2. The installer runs inside the distro - not on the Windows host
3. Anthropic is the trusted vendor for this tool

## Condition for revisiting

If Anthropic publishes Claude Code via a package manager (apt, npm, brew, or winget),
use that instead. Package manager distributions provide cryptographic verification,
version pinning, and reproducible installs.

Monitor: https://github.com/anthropics/claude-code for distribution updates.

## Controls reference

Install integrity gap: `docs/security-posture.md` - Deployment Integrity,
Claude Code install integrity row.
