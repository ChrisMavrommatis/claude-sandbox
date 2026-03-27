# What This Is

Claude Sandbox is a pre-configured WSL2 Debian environment that isolates Claude Code from the Windows host. It is designed to reduce the blast radius if Claude acts outside its intended scope - particularly for professional work, unattended sessions, and projects containing credentials.

## Design Principles

- **Defense-in-depth**: multiple independent layers so no single misconfiguration exposes everything
- **Least privilege**: non-root default user, password-gated sudo, explicit RO/RW mount modes per project
- **Honest gap documentation**: known limitations are listed openly, not hidden (see Known Limitations below)
- **Verifiable posture**: every control is linked to a Test-Sandbox check code (e.g. S-001, S-007) so the security state can be verified after any change
- **Minimal blast radius**: Windows interop disabled, automount disabled, Windows PATH excluded - Claude cannot reach the host filesystem except through explicit mounts

## Controls Summary

| Category            | Key Controls                                                                                                               | Status                    |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| Host Isolation      | WSL2 Hyper-V boundary; interop disabled (S-001); automount disabled (S-003); Windows PATH excluded (S-002)                 | Supported                 |
| Filesystem          | Mount-on-demand (fstab-only, S-019); explicit RO/RW per project; path traversal validation (S-012)                         | Supported                 |
| Access Control      | Non-root default user (S-006); password-gated sudo (S-007); umask enforcement (S-017)                                      | Supported                 |
| Process Containment | systemd as PID 1 (S-005); bubblewrap for Claude sandbox mode (S-009)                                                       | Supported                 |
| Application Layer   | Managed settings + policy (/etc/claude-code/, I-013/I-014); command deny list; sandbox mode enforced (failIfUnavailable)   | Supported                 |
| Audit & Logging     | Timestamped bash history (S-018); git audit trail on projects                                                              | Partial - no kernel audit |

Full controls matrix with check codes: [docs/security-posture.md](docs/security-posture.md)

## Known Limitations

- No outbound network filtering at the host level (WSL2 NAT architecture constraint; sandbox network proxy for bash is planned but not yet deployed)
- Claude's built-in tools (WebFetch) are not filtered by any sandbox control
- Claude Code installed via curl-pipe-bash with no checksum verification
- Container image not pinned to digest by default
- Claude Code self-updates automatically; no version pinning is available
- Claude has full read access to the persistence mount by design - credentials stored in ~/.claude are accessible to Claude across all sessions

## More Information

- Full threat model: [docs/threat-model.md](docs/threat-model.md)
- Security controls matrix: [docs/security-posture.md](docs/security-posture.md)
- Architecture decisions: [docs/decisions/](docs/decisions/)

## Reporting Security Issues

If you discover a security issue in this project, open a GitHub issue with the title prefix [SECURITY], or contact the maintainer directly before disclosing publicly. For vulnerabilities in Claude Code itself, report to Anthropic at [HackerOne](https://hackerone.com/anthropic-vdp).
