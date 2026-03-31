# ADR-003: Password-gated sudo

- **Date:** 2026-03-27
- **Status:** Accepted

## Problem

Claude can execute bash commands autonomously, including in unattended sessions. Without
a hard control on privilege escalation, a prompt injection attack or hallucination could
cause Claude to run a sudo command without any human involvement.

## Decision

**Require a password for all sudo operations. No NOPASSWD entries.**

## What this means in practice

- Claude cannot escalate to root without a human physically typing the password
- Prompt injection via a project file or WebFetch cannot autonomously trigger sudo
- Slight friction for the user when a legitimate sudo command is needed
- Verified by S-007 - Test-Sandbox fails if any NOPASSWD entry is found

## Accepted risk

A user who pre-caches their sudo credential (via `sudo -v`) within the timeout window
effectively removes this control for the duration of that session. This is a conscious
user choice, not a sandbox failure.

## Why this matters more than it seems

The password is not there to protect against the user - it is there to protect against
Claude. The design principle is that security controls must not depend on Claude
behaving correctly. Claude may be prompt-injected, hallucinating, or misunderstanding
its scope. The sudo password ensures a human must be present and consenting before any
privilege escalation occurs.

## Controls reference

Sudo password enforcement: S-007.
Sudo brute-force limiting: not implemented - see
`docs/security-posture.md` (User & Privilege, Sudo brute-force limiting row).
