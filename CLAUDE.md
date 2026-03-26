# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**Claude Sandbox** automates the creation of an isolated WSL2 (Windows Subsystem for Linux 2) Debian environment pre-configured for Claude Code development. It bridges Windows and Linux by exporting a container image as a WSL2 distro and wiring up on-demand project mounting via drvfs.

## Running the Installer

From an elevated PowerShell prompt on the Windows host:

```powershell
.\Install-ClaudeSandbox.ps1
```

Runtime profile management:
```powershell
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

| File | Role |
|------|------|
| `sandbox-config.ps1` | All user-editable config: paths, passwords, container runtime, package list, distro name, terminal profile |
| `Install-ClaudeSandbox.ps1` | Thin wrapper - loads config, calls `Install-Sandbox` |
| `Uninstall-ClaudeSandbox.ps1` | Thin wrapper - loads config, calls `Uninstall-Sandbox` |
| `Change-Profile.ps1` | Thin wrapper - loads config, calls `Set-SandboxProfile` |
| `Change-Workflow.ps1` | Thin wrapper - loads config, calls `Set-SandboxWorkflow` |
| `ClaudeSandbox/ClaudeSandbox.psd1` | PowerShell module manifest |
| `ClaudeSandbox/ClaudeSandbox.psm1` | Module loader - dot-sources Private/ then Public/ |
| `ClaudeSandbox/Public/Install-Sandbox.ps1` | Full install orchestration: WSL setup, container, packages, user, persistence, profile, workflow, terminal |
| `ClaudeSandbox/Public/Uninstall-Sandbox.ps1` | Terminates and unregisters distro, removes terminal profile; never touches `$ClaudePersistenceDir` |
| `ClaudeSandbox/Public/Set-SandboxProfile.ps1` | Interactive bashrc profile picker and deployment |
| `ClaudeSandbox/Public/Set-SandboxWorkflow.ps1` | Interactive workflow picker with token replacement and deployment |
| `ClaudeSandbox/Public/Add-TerminalProfile.ps1` | Adds/updates Windows Terminal profile for the distro |
| `ClaudeSandbox/Public/Remove-TerminalProfile.ps1` | Removes Windows Terminal profile entry |
| `ClaudeSandbox/Public/Invoke-InSandbox.ps1` | Executes a bash command inside the WSL distro |
| `ClaudeSandbox/Public/Restart-Sandbox.ps1` | Terminates and waits for distro restart |
| `ClaudeSandbox/Assets/wsl.conf` | WSL2 config template (systemd, GPU, no Windows interop) |
| `ClaudeSandbox/Assets/profiles/default.sh` | Standard Debian bashrc that sources `~/.bashrc.d/workflow.sh` |
| `ClaudeSandbox/Assets/profiles/pretty.sh` | Enhanced bashrc with colored prompt and archive extractor utility |
| `ClaudeSandbox/Assets/workflows/default.sh` | Bash functions (`index-projects`, `mount-project`, `switch-project`) with tab completion and welcome banner |
| `docs/setup-commands.md` | Step-by-step manual setup guide (no installer) |

### Module Pattern

The project uses a **"thin script, fat module"** pattern:
- All logic lives inside the `ClaudeSandbox` PowerShell module (`ClaudeSandbox/Public/*.ps1`)
- Root-level `.ps1` scripts are thin wrappers: import module, load config, call one public function
- Private helpers (`ClaudeSandbox/Private/*.ps1`) handle formatting, assertions, and file operations
- All public functions accept a `[hashtable]$Config` parameter built from `sandbox-config.ps1` variables

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

Workflow scripts use `__TOKEN__` placeholders (e.g., `__PROJECTS_DRVFS__`) that `Set-SandboxWorkflow` and `Install-Sandbox` replace with actual Windows paths before deploying into the sandbox. This avoids hardcoding Windows paths in shell scripts.

### Persistence

Claude Code's `.claude` directory is bind-mounted from a Windows folder (`$ClaudePersistenceDir`) via `/etc/fstab` so Claude state, settings, and memory survive distro rebuilds. A symlink `~/.claude.json → ~/.claude/.claude.json` ensures Claude's top-level config file is also persisted.

### Profile & Workflow System

- **Profile** (`ClaudeSandbox/Assets/profiles/*.sh`) - replaces `~/.bashrc` entirely. The default profile sources `~/.bashrc.d/workflow.sh` at the end.
- **Workflow** (`ClaudeSandbox/Assets/workflows/*.sh`) - deployed to `~/.bashrc.d/workflow.sh`. Contains project management functions and the welcome banner.
