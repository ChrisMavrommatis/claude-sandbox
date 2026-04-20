# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**Claude Sandbox** automates the creation of an isolated WSL2 Debian environment
pre-configured for Claude Code. It exports a container image as a WSL2 distro and
wires up on-demand project mounting via drvfs.

**Design principles (non-negotiable):**

- **Defense-in-depth**: multiple independent layers so no single misconfiguration exposes everything
- **Least privilege**: non-root user, password-gated sudo, explicit RO/RW mount modes per project
- **Honest gap documentation**: limitations listed openly, never hidden
- **Verifiable posture**: every security claim links to a check code (S-xxx, I-xxx) in Test-Sandbox.ps1
- **Minimal blast radius**: Windows interop, automount, and PATH disabled - Claude cannot reach the host filesystem except through explicit mounts

---

## Rules

Coding, documentation, and markdown conventions that apply to all work in this repository.

### Coding

- Never use em dashes. Use regular hyphens (`-`) instead.
- **Verification check codes**: Every piece of code that creates or configures something
  verified by `Test-Sandbox` must have a `# [X-NNN]` comment on or near the responsible
  line. When adding new installer steps or security settings, add a corresponding check
  to `Test-Sandbox` with the next available code and annotate the source. When modifying
  existing checked code, preserve the annotation.
- **PowerShell path quoting**: Always wrap path and identifier variables in double quotes
  when passing them to external commands (wsl, podman, docker) or PowerShell cmdlets
  (Test-Path, New-Item, Remove-Item, Get-ChildItem, etc.). Windows paths can contain
  spaces and unquoted variables in external command calls can silently shift argument
  positions. Use `"$var"` for simple variables and `"$($expr)"` for property access or
  expressions:

  ```powershell
  # External commands - quote all variable arguments
  wsl --import "$DistroName" "$InstallDir" "$TarPath" --version 2
  wsl -d "$DistroName" --user "$User" -- bash -c "$Command"

  # Cmdlets - quote path variables
  Test-Path "$InstallDir"
  Remove-Item "$TarPath" -Recurse
  New-Item -ItemType Directory -Path "$path"
  ```

- **Write-FileToDistro staging**: Never write directly to `/etc/` or any root-owned path
  via `Write-FileToDistro`. Always stage to `/tmp/` first:

  ```powershell
  Write-FileToDistro $DistroName "/tmp/filename" $content
  Invoke-InSandbox $DistroName "mv /tmp/filename /target/path && chmod NNN /target/path"
  ```

### Documentation

- **Keep documentation in sync**:
  - `README.md` - update when commands, scripts, or user-facing behaviour changes.
  - `CLAUDE.md` - update when architecture, functions, or coding conventions change.
  - `docs/security-posture.md` - operational reference (what controls exist, are they
    working?). Update ONLY when implementing or resolving a security control.
  - `docs/threat-model.md` - threat reasoning (what we defend against and why). Update
    ONLY when the threat landscape, trust boundaries, accepted risks, or STRIDE analysis
    changes.
  - `docs/security-research.md` - update ONLY when explicitly implementing or resolving
    a security control or gap.
  - Do NOT modify any of these files as a side effect of unrelated changes. If a change
    has security implications but you were not asked to update them, flag it instead.
  - Documentation should never describe something that doesn't exist or omit something
    that does.
- **When implementing a security control**, all five of these must update together:
  1. `Test-Sandbox.ps1` - add or update the check
  2. `CLAUDE.md` - add check code to the table
  3. `docs/security-posture.md` - update Status and Check columns
  4. `docs/threat-model.md` - update STRIDE row Status; remove from Section 8 if now
     implemented
  5. `SECURITY.md` / `docs/about.md` - update Known Limitations if relevant
- **security-posture.md integrity**: When reviewing or editing `docs/security-posture.md`:
  - "Supported" status requires a check code in the Check column
  - "Not Supported" status must NOT have a check code
  - "Partial" status may have a check code if a partial check exists
- **Never claim a control is implemented** without both: a `# [X-NNN]` annotation on
  the source line that produces the verified state, AND a corresponding check in
  `Test-Sandbox.ps1`. A "Supported" label without both does not count as implemented.
- **Security domain assignment**: Every new check code (I-xxx or S-xxx) must map to one
  of the eight canonical security domains. If a proposed check does not fit any existing
  domain, stop - do not create it and do not add a new domain without an explicit
  decision to expand the canonical set.

### Markdown

- **Table formatting**: Align separator rows to match column widths using dashes. Pad
  cell content with spaces to match the widest entry in each column so tables are
  readable in plain text.
- **Heading levels (MD001)**: Increment by one at a time. Never jump from `##` to `####`.
- **Blank lines around headings (MD022)**: One blank line above and below every heading.
- **Blank lines around lists (MD032)**: One blank line before and after every list.

---

## Architecture

How the project is structured - the layers it runs across, the module pattern, and the key mechanisms that wire everything together.

### Layers

1. **Windows Host** - PowerShell module + thin wrapper scripts orchestrate WSL2 distro creation, package installation, and user setup.
2. **Container Bootstrap** - Podman or Docker exports a `debian:bookworm-slim` rootfs that becomes the WSL2 distro.
3. **WSL2 Linux** - Isolated Debian environment with systemd, bubblewrap (for Claude's sandbox mode), socat, and fzf.
4. **Project Bridge** - `drvfs` mounts connect Windows project folders into Linux on demand with read-write or read-only access.

### Module Pattern

The project uses a **"thin script, fat module"** pattern:

- All logic lives inside the `ClaudeSandbox` PowerShell module (`ClaudeSandbox/Public/*.ps1`)
- Root-level `.ps1` scripts are thin wrappers: import module, load config, call one public function
- Private helpers (`ClaudeSandbox/Private/*.ps1`) handle formatting, assertions, and file operations
- All public functions accept a `[hashtable]$Config` parameter built from `sandbox-config.ps1` variables
- `Invoke-InSandbox` and `Restart-Sandbox` use explicit parameters (low-level utilities called many times)
- **Interactive UI belongs in thin wrappers, not in module functions.** Module functions
  accept a fully populated `$Config` and execute without prompting, keeping the module
  scriptable for CI.

**Thin wrapper template** (all root scripts follow this pattern):

```powershell
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\ClaudeSandbox\ClaudeSandbox.psd1" -Force
. "$PSScriptRoot\sandbox-config.ps1"   # provides $Config

<Public-Function> -Config $Config
```

**Function parameter conventions:**

| Pattern                         | Used by               | Why                                                                    |
| ------------------------------- | --------------------- | ---------------------------------------------------------------------- |
| `[hashtable]$Config`            | All public functions  | Single config object from `sandbox-config.ps1`                         |
| `$DistroName, $Command, $User`  | `Invoke-InSandbox`    | Low-level utility called many times with varying args                  |
| `$DistroName`                   | `Restart-Sandbox`     | Low-level utility, only needs one value                                |
| `$Config + $ProfileName`        | `Set-SandboxProfile`  | Config for distro/user, explicit name for the profile to deploy        |
| `$Config + $WorkflowName`       | `Set-SandboxWorkflow` | Config for distro/user/paths, explicit name for the workflow to deploy |
| `$Config + $PolicyName`         | `Set-SandboxPolicy`   | Config for distro, explicit name for the policy folder to deploy       |

### Token Replacement

Workflow scripts use `__TOKEN__` placeholders (e.g., `__PROJECTS_DRVFS__`) that
`Set-SandboxWorkflow` and `Install-Sandbox` replace with actual Windows paths before
deploying. The `wsl.conf` template uses `__DistroName__` and `__Username__` tokens.
This avoids hardcoding Windows paths in shell scripts.

### Persistence

Claude Code's `.claude` directory is bind-mounted from a Windows folder
(`$ClaudePersistenceDir`) via `/etc/fstab` so Claude state, settings, and memory
survive distro rebuilds. A symlink `~/.claude.json -> ~/.claude/.claude.json` ensures
Claude's top-level config file is also persisted.

### Profile, Workflow & Policy System

- **Profile** (`ClaudeSandbox/Assets/profiles/*.sh`) - replaces `~/.bashrc` entirely.
  The default profile sources `~/.bashrc.d/workflow.sh`.
- **Workflow** (`ClaudeSandbox/Assets/workflows/*.sh`) - deployed to
  `~/.bashrc.d/workflow.sh`. Contains project management functions and the welcome
  banner.
- **Policy** (`ClaudeSandbox/Assets/policies/<name>/`) - each subfolder contains
  `settings.json` (Claude Code managed permissions) and `policy.md` (deployed as
  `/etc/claude-code/CLAUDE.md`). Three tiers:
  - `default` - blocks catastrophic disk operations only (`rm -rf /*`, `dd`, `mkfs`). Sandbox opt-in.
  - `restrictive` - adds curl, wget, git push, package managers. Sandbox opt-in.
  - `maximum` - same deny rules; `sandbox.enabled = true`.

| Policy      | Deny rules                                                  | allowedDomains | sandbox.enabled |
| ----------- | ----------------------------------------------------------- | -------------- | --------------- |
| default     | rm -rf /*, dd, mkfs                                         | No             | Not set         |
| restrictive | + curl, wget, git push, chmod 777, pip, npm, apt (12 total) | Yes            | Not set         |
| maximum     | Same 12                                                     | Yes            | true            |

All tiers deploy the PreToolUse credential guard hook.
Policy files live in `ClaudeSandbox/Assets/policies/<tier>/settings.json` and `policy.md`.

---

## Key Files

**Root-level scripts** (thin wrappers - import module, load config, call one public function):

| File                          | Calls                                          |
| ----------------------------- | ---------------------------------------------- |
| `Install-ClaudeSandbox.ps1`   | `Install-Sandbox`                              |
| `Uninstall-ClaudeSandbox.ps1` | `Uninstall-Sandbox`                            |
| `Change-Profile.ps1`          | `Set-SandboxProfile`                           |
| `Change-Workflow.ps1`         | `Set-SandboxWorkflow`                          |
| `Change-Policy.ps1`           | `Set-SandboxPolicy`                            |
| `Verify-ClaudeSandbox.ps1`    | `Test-Sandbox`                                 |
| `sandbox-config.ps1`          | Defines `$Config`; dot-sourced by all wrappers |

**Public functions** (`ClaudeSandbox/Public/`):

| Function                 | Role                                                                                                                                            |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `Install-Sandbox`        | Full install orchestration: WSL setup, container, packages, user, persistence, profile, workflow, terminal. Requires fully populated `$Config`. |
| `Uninstall-Sandbox`      | Terminates and unregisters distro, removes terminal profile; never touches `$ClaudePersistenceDir`. `-RemoveInstallDir` to delete disk files.   |
| `Set-SandboxProfile`     | Deploys a named bashrc profile (e.g., `default.sh`, `pretty.sh`)                                                                                |
| `Set-SandboxWorkflow`    | Deploys a named workflow with token replacement (e.g., `default.sh`)                                                                            |
| `Add-TerminalProfile`    | Adds/updates Windows Terminal profile for the distro                                                                                            |
| `Remove-TerminalProfile` | Removes Windows Terminal profile entry                                                                                                          |
| `Invoke-InSandbox`       | Executes a bash command inside the WSL distro (default user: root)                                                                              |
| `Restart-Sandbox`        | Terminates distro and waits for restart                                                                                                         |
| `Set-SandboxPolicy`      | Deploys a named managed policy (settings.json + policy.md) from `Assets/policies/<name>/`                                                       |
| `Test-Sandbox`           | Verifies installation and security posture                                                                                                      |

**Private helpers** (`ClaudeSandbox/Private/`):

| Function               | Role                                                            |
| ---------------------- | --------------------------------------------------------------- |
| `Assert-Administrator` | Exits if not running as admin                                   |
| `Assert-ExitCode`      | Exits with formatted error if `$LASTEXITCODE` is non-zero       |
| `Get-AssetPath`        | Resolves paths relative to `ClaudeSandbox/Assets/`              |
| `Initialize-Directory` | Creates directory if it doesn't exist                           |
| `Write-Banner`         | Formatted header with title and key-value fields                |
| `Write-FileToDistro`   | Writes UTF-8 no-BOM content to distro via `\\wsl$\` UNC path    |
| `Write-Info`           | DarkCyan info message                                           |
| `Write-Ok`             | Green success message                                           |
| `Write-Step`           | Blue step heading                                               |

**Assets** (`ClaudeSandbox/Assets/`):

| File                                   | Role                                                                                                        |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `wsl.conf`                             | WSL2 config template with `__DistroName__` and `__Username__` tokens                                        |
| `session-timeout.sh`                   | Session timeout template; `__SESSION_TIMEOUT__` token replaced at install time                              |
| `.wslconfig.template`                  | WSL2 resource limits reference (memory, CPU, swap); user copies to host manually                            |
| `hooks/pretooluse-credential-guard.sh` | PreToolUse hook that blocks credential file reads; deployed by `Set-SandboxPolicy`                          |
| `profiles/default.sh`                  | Standard Debian bashrc that sources `~/.bashrc.d/workflow.sh`                                               |
| `profiles/pretty.sh`                   | Enhanced bashrc with colored prompt and archive extractor utility                                           |
| `workflows/default.sh`                 | Bash functions (`index-projects`, `mount-project`, `switch-project`) with tab completion and welcome banner |
| `policies/default/settings.json`       | Permissive tier: blocks catastrophic disk operations only                                                   |
| `policies/default/policy.md`           | Policy text for default tier                                                                                |
| `policies/restrictive/settings.json`   | Restrictive tier: adds curl/wget deny rules                                                                 |
| `policies/restrictive/policy.md`       | Policy text for restrictive tier                                                                            |
| `policies/maximum/settings.json`       | Maximum tier: enforces sandbox, blocks package managers and git push                                        |
| `policies/maximum/policy.md`           | Policy text for maximum tier                                                                                |

**Documentation** (`docs/`):

| File                     | Role                                                                                                                                   |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| `about.md`               | Plain-English explanation of what the sandbox is and who it is for                                                                     |
| `threat-model.md`        | What we defend against and why: STRIDE analysis, trust boundary diagram, accepted risks with justifications, reasoning behind controls |
| `setup-commands.md`      | Step-by-step manual setup guide (no installer)                                                                                         |
| `safe-usage.md`          | User-facing guide to using Claude safely inside the sandbox                                                                            |
| `security-posture.md`    | Operational reference: what controls exist and are they working? Controls matrix with check codes, Supported / Partial / Not Supported |
| `security-research.md`   | Research notes: blocked controls, WSL2 limitations, feasibility findings                                                               |
| `decisions/README.md`    | ADR index                                                                                                                              |
| `decisions/ADR-001..009` | Architecture Decision Records (WSL2, iptables, sudo, persistence, curl-pipe-bash, audit tooling, process containment, image digest pinning, managed settings enforcement scope) |

---

## Verification Check Codes

Every installer step and security setting that `Test-Sandbox` verifies is annotated
with a `# [X-NNN]` comment in the source. When adding new checks: assign the next code
in sequence, add the check to `Test-Sandbox`, and annotate the source line.

### Security Domains

Eight canonical domains classify every control and check code.
Use these names verbatim everywhere.

| Domain               | Scope                                                                                      |
| -------------------- | ------------------------------------------------------------------------------------------ |
| Host Isolation       | WSL2 boundary, Windows interop, automount, PATH, GPU passthrough, outbound network         |
| Filesystem           | Mount configuration, fstab entries, project mount modes, path validation, persistence      |
| User & Privilege     | User identity, sudo, passwords, umask, session timeout, file permission checks             |
| Process Containment  | systemd, bubblewrap namespaces, resource limits, MAC enforcement                           |
| Application Layer    | Claude permission modes, managed settings, hooks, command blocklists, per-project policies |
| Audit & Logging      | Git trail, bash history, system logging, runtime detection tools                           |
| Deployment Integrity | Token replacement, image pinning, install integrity, line endings, package verification    |
| Admin Operations     | Installer elevation, post-install checks, update mechanism, uninstall, temp cleanup        |

### Code Index

| Code      | Domain               | Check                                                                          |
| --------- | -------------------- | ------------------------------------------------------------------------------ |
| `I-001`   | Admin Operations     | Distro registered in WSL                                                       |
| `I-002`   | User & Privilege     | User exists and is non-root                                                    |
| `I-003`   | User & Privilege     | User in sudo group                                                             |
| `I-004.N` | Deployment Integrity | Required package N installed (one per package)                                 |
| `I-005`   | Host Isolation       | wsl.conf exists                                                                |
| `I-006`   | Admin Operations     | .bashrc deployed                                                               |
| `I-007`   | Admin Operations     | Workflow script deployed                                                       |
| `I-008`   | Filesystem           | .claude persistence directory exists                                           |
| `I-009`   | Filesystem           | .claude mount configured in fstab                                              |
| `I-010`   | Filesystem           | .claude.json symlink exists                                                    |
| `I-011`   | Filesystem           | Projects directory exists                                                      |
| `I-012`   | Application Layer    | Claude Code installed (warn-only)                                              |
| `I-013`   | Application Layer    | Managed settings deployed (allowManagedPermissionRulesOnly unverified - see ADR-009) |
| `I-014`   | Application Layer    | Managed policy deployed                                                        |
| `I-015`   | Application Layer    | PreToolUse credential guard hook deployed                                      |
| `I-015.N` | Application Layer    | One sub-check per fixture in Tests/Hooks/ (blocked-* expects exit 2, allowed-* expects exit 0) |
| `S-001`   | Host Isolation       | Windows interop disabled                                                       |
| `S-002`   | Host Isolation       | Windows PATH excluded                                                          |
| `S-003`   | Host Isolation       | Automount disabled                                                             |
| `S-004`   | Host Isolation       | protectBinfmt enabled                                                          |
| `S-005`   | Process Containment  | systemd enabled                                                                |
| `S-006`   | User & Privilege     | Default user is non-root                                                       |
| `S-007`   | User & Privilege     | Sudo is password-gated (no NOPASSWD)                                           |
| `S-008`   | User & Privilege     | Sudo password feedback enabled (warn-only)                                     |
| `S-009`   | Process Containment  | Unprivileged user namespaces enabled                                           |
| `S-010`   | Filesystem           | fstab mount has umask=022                                                      |
| `S-011`   | Filesystem           | fstab mount has metadata flag                                                  |
| `S-012`   | Filesystem           | Project name validation rejects path traversal                                 |
| `S-013`   | User & Privilege     | Password changed from default (warn-only)                                      |
| `S-014`   | Host Isolation       | GPU setting matches config                                                     |
| `S-015`   | User & Privilege     | wsl.conf owned by root, not world-writable                                     |
| `S-016`   | User & Privilege     | sudoers.d/pwfeedback has correct permissions (0440)                            |
| `S-017`   | User & Privilege     | umask 022 enforced in profile                                                  |
| `S-018`   | Audit & Logging      | History timestamps enabled (HISTTIMEFORMAT)                                    |
| `S-019`   | Filesystem           | fstab-only mounts enabled (mountFsTab = true)                                  |
| `S-020`   | User & Privilege     | Session timeout configured (when SessionTimeout > 0)                           |
| `S-021`   | Application Layer    | Managed settings deny catastrophic commands                                    |
| `S-022`   | Deployment Integrity | Distro image is digest-pinned (warn-only)                                      |

---

## Maintenance

- After any change to security controls or documentation, verify:
  - Controls marked Supported in `security-posture.md` without a check code are verified by design or by inspection rather than automated test.
  - No Not Supported row has one.
  - Section 8 of `threat-model.md` contains only unimplemented controls.
  - `security-research.md` has no duplicate sections or stale "planned" claims for controls now deployed.
  - The check code table here matches `Test-Sandbox.ps1` exactly.
- Do not rewrite content for style. Only correct factual errors, stale claims, and
  structural noise. If in doubt, flag it rather than change it.
- After each task, state what files changed, what check codes were added or modified,
  and whether documentation was updated.
- If you find a bug or inconsistency outside the assigned task, fix it and note it -
  do not silently skip it.
