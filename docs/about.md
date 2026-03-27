# Purpose

## What It Is

Claude Sandbox is a pre-configured WSL2 Debian environment for running Claude Code in isolation from the Windows host. The installer automates distro creation, security hardening, persistence setup, and project mounting in a single command.

## The Problem It Solves

When Claude Code runs directly on a developer's machine, it has access to the entire filesystem, the Windows PATH, and the network. For personal projects this may be acceptable. For professional work - client code, projects with credentials, unattended runs - this is a meaningful risk. Claude Sandbox narrows what Claude can reach and limits the blast radius if something goes wrong.

## Who It Is For

- Developers who run Claude Code on client or commercially sensitive code
- Developers who run Claude unattended (Claude working while the developer does something else)
- Developers whose projects contain API keys, connection strings, or .env files
- Teams who want a consistent, auditable Claude Code environment
- Developers who want to recover quickly if Claude makes a mistake (git audit trail, isolated environment that can be rebuilt in one command)

## What It Does Not Do

- Does not prevent Claude from reading files it has access to within the sandbox. If a project with credentials is mounted read-write, Claude can read those credentials.
- Does not filter Claude's own built-in network tools. WebFetch is not sandboxed.
- Does not guarantee Claude cannot make mistakes - it limits the blast radius.
- Does not replace reviewing Claude's output before committing it.
- Is not a substitute for secrets management. Do not store production credentials in project directories that will be mounted into the sandbox.

## Security Posture

For the full security coverage matrix, see [plans/security-posture.md](../plans/security-posture.md). For the threat model, see [threat-model.md](threat-model.md). For vulnerability reporting, see [SECURITY.md](../SECURITY.md).
