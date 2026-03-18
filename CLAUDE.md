# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**Claude Sandbox** automates the creation of an isolated WSL2 (Windows Subsystem for Linux 2) Debian environment pre-configured for Claude Code development. It bridges Windows and Linux by exporting a container image as a WSL2 distro and wiring up on-demand project mounting via drvfs.

## Running the Installer

From an elevated PowerShell prompt on the Windows host:

```powershell
.\src\Install-ClaudeSandbox.ps1
```

Runtime profile management:
```powershell
.\src\Change-Profile.ps1     # Switch bashrc profile interactively
.\src\Change-Workflow.ps1    # Switch workflow profile interactively
```

Inside the WSL sandbox:
```bash
index-projects                    # Scan Windows Projects folder and build index
switch-project                    # fzf picker — mount + cd into a project (RW)
switch-project <name>             # Mount + cd into a named project (RW)
mount-project <name> [--ro|--rw]  # Mount without changing directory
unmount-project <name>            # Safely unmount
```

## Architecture

### Layers

1. **Windows Host** (`src/*.ps1`) — PowerShell orchestrates WSL2 distro creation, package installation, and user setup.
2. **Container Bootstrap** — Podman or Docker exports a `debian:bookworm-slim` rootfs that becomes the WSL2 distro.
3. **WSL2 Linux** — Isolated Debian environment with systemd, bubblewrap (for Claude's sandbox mode), socat, and fzf.
4. **Project Bridge** — `drvfs` mounts connect Windows project folders into Linux on demand with read-write or read-only access.

### Key Files

| File | Role |
|------|------|
| `src/sandbox-config.ps1` | All user-editable config: paths, passwords, container runtime, package list, distro name |
| `src/Install-ClaudeSandbox.ps1` | Main installer — reads config, calls container runtime, invokes WSL, deploys everything |
| `src/common.ps1` | Shared PowerShell helpers: `Execute-InSandbox`, `Write-Step/Ok/Info`, `Check-ExitCode` |
| `src/wsl.conf` | WSL2 config template embedded into the distro (systemd, GPU, no Windows interop) |
| `src/Change-Profile.ps1` | Interactively deploys a bashrc profile from `src/profiles/` into the sandbox |
| `src/Change-Workflow.ps1` | Interactively deploys a workflow script from `src/workflows/` into the sandbox |
| `src/Remove-ClaudeSandbox.ps1` | Terminates and unregisters the distro, optionally removes the install directory; never touches `$ClaudePersistenceDir` |
| `src/workflows/default.sh` | Bash functions (`index-projects`, `mount-project`, `switch-project`) with tab completion and welcome banner |
| `src/profiles/default.sh` | Standard Debian bashrc that sources `~/.bashrc.d/workflow.sh` |
| `src/profiles/pretty.sh` | Enhanced bashrc with colored prompt and archive extractor utility |
| `docs/setup-commands.md` | Step-by-step manual setup guide (no installer) |

### Configuration

Edit `src/sandbox-config.ps1` before running the installer. Key variables:

- `$ProjectsPath` — Windows root for projects (mounted into Linux on demand)
- `$ClaudePersistenceDir` — Windows folder where `.claude` state is persisted across distro rebuilds
- `$ContainerRuntime` — `podman` or `docker`
- `$Packages` — Extra apt packages to install in the distro
- `$Username` / `$DistroName` / `$InstallDir` — Distro identity and install location

### Token Replacement Pattern

Workflow scripts use `__TOKEN__` placeholders (e.g., `__PROJECTS_DRVFS__`) that `Change-Workflow.ps1` and the installer replace with actual Windows paths before deploying into the sandbox. This avoids hardcoding Windows paths in shell scripts.

### Persistence

Claude Code's `.claude` directory is bind-mounted from a Windows folder (`$ClaudePersistenceDir`) via `/etc/fstab` so Claude state, settings, and memory survive distro rebuilds. A symlink `~/.claude.json → ~/.claude/.claude.json` ensures Claude's top-level config file is also persisted.

### Profile & Workflow System

- **Profile** (`src/profiles/*.sh`) — replaces `~/.bashrc` entirely. The default profile sources `~/.bashrc.d/workflow.sh` at the end.
- **Workflow** (`src/workflows/*.sh`) — deployed to `~/.bashrc.d/workflow.sh`. Contains project management functions and the welcome banner.
