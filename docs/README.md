# Documentation

This directory contains operational and security documentation for Claude Sandbox.

| File                                        | Purpose                                                                                     |
| ------------------------------------------- | ------------------------------------------------------------------------------------------- |
| [about.md](about.md)                        | Plain-English overview of what the sandbox is and who it is for                             |
| [safe-usage.md](safe-usage.md)              | User guide: mount control, permission modes, sandbox mode, secrets, backup                  |
| [setup-commands.md](setup-commands.md)      | Step-by-step manual setup guide (no installer)                                              |
| [threat-model.md](threat-model.md)          | What the sandbox defends against: assets, scenarios, STRIDE analysis, accepted risks        |
| [security-posture.md](security-posture.md)  | Controls reference: what controls exist, their status, and verification check codes         |
| [security-research.md](security-research.md)| Open investigations, deferred items, and scope boundaries                                   |
| [decisions/](decisions/)                    | Architecture Decision Records (ADR-001 through ADR-009) — see decisions/README.md for index |

## Where to look for what

- **Understanding the project**: start with [about.md](about.md)
- **Using Claude safely day-to-day**: [safe-usage.md](safe-usage.md)
- **What threats are in scope**: [threat-model.md](threat-model.md)
- **Whether a specific control is implemented**: [security-posture.md](security-posture.md)
- **Why a control is missing or deferred**: [security-research.md](security-research.md) or the relevant [ADR](decisions/)
- **Why a design decision was made**: [decisions/](decisions/)