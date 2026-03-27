# ADR-003: Password-gated sudo

**Date:** 2026-03-27
**Status:** Accepted

## Context

This is a local developer sandbox. The user owns the machine and knows the sudo password. The question is: why enforce password-gated sudo instead of NOPASSWD, which would be more convenient?

## Decision

Require a password for all sudo operations. No NOPASSWD entries in sudoers.

## Consequences

- Slight friction when the user legitimately needs to run a sudo command
- Claude cannot escalate to root without a human typing a password
- Verified by check S-007; Test-Sandbox will fail if NOPASSWD is found

## Security Implications

The password requirement is not for the user - it is a control against Claude. Prompt injection is a realistic attack vector: malicious content in a project file or a web page Claude fetches could instruct Claude to run a sudo command. Without a password requirement, Claude could execute that instruction autonomously, particularly in an unattended session.

The design principle here is that security controls must not depend on Claude behaving correctly. Claude may be prompt-injected, hallucinating, or misunderstanding its scope. The sudo password is a hard control that requires a human to be present and consenting before any privilege escalation occurs.
