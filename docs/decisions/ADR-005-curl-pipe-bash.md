# ADR-005: curl-pipe-bash

**Date:** 2026-03-27
**Status:** Accepted

## Context

Claude Code is installed using Anthropic's official installer:

    curl -fsSL https://claude.ai/install.sh | bash

This pattern (curl-pipe-bash) downloads and immediately executes a shell script with no checksum verification, no signature check, and no opportunity to inspect the script before it runs.

## Decision

Use the official Anthropic installer as-is. No alternative distribution mechanism exists. An interim improvement - downloading the script to a temp file before executing it - allows the user to inspect the content but provides no security guarantee since there is no known-good hash to verify against.

## Consequences

- Install is straightforward and tracks Anthropic's official distribution
- No version pinning - the script installs whatever Claude Code version is current at install time
- Users who want to inspect the script can download it first manually

## Security Implications

HTTPS protects against network-level MITM but does not protect against:
- Server-side compromise of claude.ai
- CDN poisoning
- Time-of-check / time-of-use substitution between download and execution

The hash changes with every Claude Code release, making a known-good comparison impractical without a publisher-maintained checksum file (which Anthropic does not currently provide).

This risk is accepted because:
1. No alternative distribution exists
2. The blast radius is limited - the installer runs inside the WSL2 sandbox, not on the Windows host
3. Anthropic is a trusted vendor for this tool

**Condition for revisiting this decision:** If Anthropic publishes Claude Code via a package manager (apt, npm, brew, or winget), that distribution should be used instead. Package manager distributions provide cryptographic verification, version pinning, and reproducible installs. Monitor https://github.com/anthropics/claude-code for distribution updates.
