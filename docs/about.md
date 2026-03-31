# About Claude Sandbox

## What It Is

Claude Sandbox is a pre-configured WSL2 Debian environment for running Claude Code in isolation from the Windows host.
The installer automates distro creation, security hardening, persistence setup, and project mounting in a single command.

## The Problem It Solves

When Claude Code runs directly on a developer's machine, it has access to the entire filesystem, the Windows PATH, and the network.
For personal projects this may be acceptable. For professional work - client code, projects with credentials, unattended runs - this is a meaningful risk.
Claude Sandbox narrows what Claude can reach and limits the blast radius if something goes wrong.

## Who It Is For

- Developers running Claude Code on client or commercially sensitive code
- Developers running Claude unattended while they focus on something else
- Developers whose projects contain API keys, connection strings, or `.env` files
- Teams who want a consistent, auditable Claude Code environment
- Developers who want to recover quickly from a mistake (git audit trail, environment
  that can be rebuilt in one command)

## What It Does Not Do

- **Does not prevent Claude reading files it has access to.** If a project with credentials is mounted RW, Claude can read those credentials.
- **Does not filter Claude's built-in network tools.** WebFetch is not sandboxed.
- **Does not guarantee Claude cannot make mistakes.** It limits the blast radius, not the probability of error.
- **Does not replace reviewing Claude's output** before committing or deploying it.

## Security Posture

The sandbox uses a defense-in-depth approach.
No single control covers everything - the controls work together so a gap in one layer does not expose the whole system.
Every control maps to a `Test-Sandbox` check code so the posture can be verified after any change.

Key control categories: host isolation, filesystem & mounts, access control, process containment, application-layer policy, and audit logging.

Full controls matrix, check codes, and known limitations:

- [docs/security-posture.md](security-posture.md)
- [SECURITY.md](../SECURITY.md)

## More Information

- [Threat model](threat-model.md)
- [Security controls matrix](security-posture.md)
- [Architecture decisions](decisions/)
- [Safe usage guide](safe-usage.md)