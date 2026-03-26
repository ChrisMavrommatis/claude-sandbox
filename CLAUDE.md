# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Style Rules

- Never use em dashes. Use regular hyphens (`-`) or double hyphens (`--`) instead.
- **Verification check codes**: Every piece of code that creates or configures something verified by `Test-Sandbox` must have a `# [X-NNN]` comment on or near the responsible line. This links the implementation to its verification check. When adding new installer steps or security settings, add a corresponding check to `Test-Sandbox` with the next available code, and annotate the source. When modifying existing checked code, preserve the code annotation. See the check code table below for the full list.

## What This Project Is

**Claude Sandbox** automates the creation of an isolated WSL2 (Windows Subsystem for Linux 2) Debian environment pre-configured for Claude Code development. It bridges Windows and Linux by exporting a container image as a WSL2 distro and wiring up on-demand project mounting via drvfs.

## Running the Installer

From an elevated PowerShell prompt on the Windows host:

```powershell
.\Install-ClaudeSandbox.ps1
```

Runtime profile management:
```powershell
.\Verify-ClaudeSandbox.ps1        # Verify installation and security posture
.\Change-Profile.ps1              # Switch bashrc profile interactively
.\Change-Workflow.ps1             # Switch workflow profile interactively
.\Uninstall-ClaudeSandbox.ps1     # Remove the distro
```

Inside the WSL sandbox:
```bash
index-projects                    # Scan Windows Projects folder and build index
switch-project                    # fzf picker - mount + cd into a project (RW)
switch-project <name>             # Mount + cd into a named project (RW)
mount-project <name> [--ro|--rw]  # Mount without changing directory
unmount-project <name>            # Safely unmount
```

## Architecture

### Layers

1. **Windows Host** - PowerShell module + thin wrapper scripts orchestrate WSL2 distro creation, package installation, and user setup.
2. **Container Bootstrap** - Podman or Docker exports a `debian:bookworm-slim` rootfs that becomes the WSL2 distro.
3. **WSL2 Linux** - Isolated Debian environment with systemd, bubblewrap (for Claude's sandbox mode), socat, and fzf.
4. **Project Bridge** - `drvfs` mounts connect Windows project folders into Linux on demand with read-write or read-only access.

### Key Files

**Root-level scripts** (thin wrappers that import module, load config, call one public function):

| File | Calls |
|------|-------|
| `Install-ClaudeSandbox.ps1` | `Install-Sandbox` |
| `Uninstall-ClaudeSandbox.ps1` | `Uninstall-Sandbox` |
| `Change-Profile.ps1` | `Set-SandboxProfile` |
| `Change-Workflow.ps1` | `Set-SandboxWorkflow` |
| `Verify-ClaudeSandbox.ps1` | `Test-Sandbox` |
| `sandbox-config.ps1` | User-editable config (not a wrapper) |

**Module - Public functions** (`ClaudeSandbox/Public/`):

| Function | Role |
|----------|------|
| `Install-Sandbox` | Full install orchestration: WSL setup, container, packages, user, persistence, profile, workflow, terminal |
| `Uninstall-Sandbox` | Terminates and unregisters distro, removes terminal profile; never touches `$ClaudePersistenceDir` |
| `Set-SandboxProfile` | Deploys a named bashrc profile (e.g., `default.sh`, `pretty.sh`) |
| `Set-SandboxWorkflow` | Deploys a named workflow with token replacement (e.g., `default.sh`) |
| `Add-TerminalProfile` | Adds/updates Windows Terminal profile for the distro |
| `Remove-TerminalProfile` | Removes Windows Terminal profile entry |
| `Invoke-InSandbox` | Executes a bash command inside the WSL distro (default user: root) |
| `Restart-Sandbox` | Terminates distro and waits for restart |
| `Test-Sandbox` | Verifies installation and security posture (23 checks) |

**Verification check codes** (used by `Test-Sandbox`):

| Code | Category | Check |
|------|----------|-------|
| `I-001` | Installation | Distro registered in WSL |
| `I-002` | Installation | User exists and is non-root |
| `I-003` | Installation | User in sudo group |
| `I-004.N` | Installation | Required package N installed (one per package) |
| `I-005` | Installation | wsl.conf exists |
| `I-006` | Installation | .bashrc deployed |
| `I-007` | Installation | Workflow script deployed |
| `I-008` | Installation | .claude persistence directory exists |
| `I-009` | Installation | .claude mount configured in fstab |
| `I-010` | Installation | .claude.json symlink exists |
| `I-011` | Installation | Projects directory exists |
| `I-012` | Installation | Claude Code installed (warn-only) |
| `S-001` | Security | Windows interop disabled |
| `S-002` | Security | Windows PATH excluded |
| `S-003` | Security | Automount disabled |
| `S-004` | Security | protectBinfmt enabled |
| `S-005` | Security | systemd enabled |
| `S-006` | Security | Default user is non-root |
| `S-007` | Security | Sudo is password-gated (no NOPASSWD) |
| `S-008` | Security | Sudo password feedback enabled (warn-only) |
| `S-009` | Security | Unprivileged user namespaces enabled |
| `S-010` | Security | fstab mount has umask=022 |
| `S-011` | Security | fstab mount has metadata flag |

**Module - Private helpers** (`ClaudeSandbox/Private/`):

| Function | Role |
|----------|------|
| `Assert-Administrator` | Exits if not running as admin |
| `Assert-ExitCode` | Exits with formatted error if `$LASTEXITCODE` is non-zero |
| `Get-AssetPath` | Resolves paths relative to `ClaudeSandbox/Assets/` |
| `Initialize-Directory` | Creates directory if it doesn't exist |
| `Write-Banner` | Formatted header with title and key-value fields |
| `Write-FileToDistro` | Writes UTF-8 no-BOM content to distro via `\\wsl$\` UNC path |
| `Write-Info` | DarkCyan info message |
| `Write-Ok` | Green success message |
| `Write-Step` | Blue step heading |

**Module - Assets** (`ClaudeSandbox/Assets/`):

| File | Role |
|------|------|
| `wsl.conf` | WSL2 config template with `__DistroName__` and `__Username__` tokens |
| `profiles/default.sh` | Standard Debian bashrc that sources `~/.bashrc.d/workflow.sh` |
| `profiles/pretty.sh` | Enhanced bashrc with colored prompt and archive extractor utility |
| `workflows/default.sh` | Bash functions (`index-projects`, `mount-project`, `switch-project`) with tab completion and welcome banner |

**Documentation:**

| File | Role |
|------|------|
| `docs/setup-commands.md` | Step-by-step manual setup guide (no installer) |
| `docs/security.md` | Security posture overview |

### Module Pattern

The project uses a **"thin script, fat module"** pattern:
- All logic lives inside the `ClaudeSandbox` PowerShell module (`ClaudeSandbox/Public/*.ps1`)
- Root-level `.ps1` scripts are thin wrappers: import module, load config, call one public function
- Private helpers (`ClaudeSandbox/Private/*.ps1`) handle formatting, assertions, and file operations
- All public functions accept a `[hashtable]$Config` parameter built from `sandbox-config.ps1` variables
- `Invoke-InSandbox` and `Restart-Sandbox` use explicit parameters (low-level utilities called many times)

### Verification Check Code Pattern

Every installer step and security setting that `Test-Sandbox` verifies is annotated with a `# [X-NNN]` comment in the source. This creates a traceable link between implementation and verification:

- `Install-Sandbox.ps1` - annotated with `[I-001]` through `[I-012]` and `[S-001]` through `[S-011]` where each resource is created
- `wsl.conf` - security settings annotated inline with `[S-001]` through `[S-006]`
- `Set-SandboxProfile.ps1` - annotated with `[I-006]`
- `Set-SandboxWorkflow.ps1` - annotated with `[I-007]` and `[I-011]`

When adding new checks: assign the next code in sequence, add the check to `Test-Sandbox`, and annotate the source line that produces the checked state.

### Configuration

Edit `sandbox-config.ps1` before running the installer. Key variables:

- `$ProjectsPath` - Windows root for projects (mounted into Linux on demand)
- `$ClaudePersistenceDir` - Windows folder where `.claude` state is persisted across distro rebuilds
- `$ContainerRuntime` - `podman` or `docker`
- `$Packages` - Extra apt packages to install in the distro
- `$Username` / `$DistroName` / `$InstallDir` - Distro identity and install location
- `$TerminalProfileName` - Display name shown in the Windows Terminal dropdown
- `$TerminalProfileIcon` - Optional icon path for the Windows Terminal profile
- `$TerminalProfileColorScheme` - Optional color scheme name (must exist in Windows Terminal settings)
- `$TerminalProfileBackground` - Optional hex background color for the Windows Terminal profile

### Token Replacement Pattern

Workflow scripts use `__TOKEN__` placeholders (e.g., `__PROJECTS_DRVFS__`) that `Set-SandboxWorkflow` and `Install-Sandbox` replace with actual Windows paths before deploying into the sandbox. The `wsl.conf` template uses `__DistroName__` and `__Username__` tokens. This avoids hardcoding Windows paths in shell scripts.

### Persistence

Claude Code's `.claude` directory is bind-mounted from a Windows folder (`$ClaudePersistenceDir`) via `/etc/fstab` so Claude state, settings, and memory survive distro rebuilds. A symlink `~/.claude.json` -> `~/.claude/.claude.json` ensures Claude's top-level config file is also persisted.

### Profile & Workflow System

- **Profile** (`ClaudeSandbox/Assets/profiles/*.sh`) - replaces `~/.bashrc` entirely. The default profile sources `~/.bashrc.d/workflow.sh` at the end.
- **Workflow** (`ClaudeSandbox/Assets/workflows/*.sh`) - deployed to `~/.bashrc.d/workflow.sh`. Contains project management functions and the welcome banner.
