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
.\src\Change-BashrcProfile.ps1   # Switch bashrc profile interactively
.\src\Change-Workflow.ps1        # Switch workflow profile interactively
```

Inside the WSL sandbox:
```bash
index-projects                   # Scan Windows Projects folder and build index
switch-project <name>            # Mount + cd into a Windows project (RW)
mount-project <name> [--ro|--rw] # Mount without changing directory
unmount-project <name>           # Safely unmount
```

## Architecture

### Layers

1. **Windows Host** (`src/*.ps1`) — PowerShell orchestrates WSL2 distro creation, package installation, and user setup.
2. **Container Bootstrap** — Podman or Docker exports a `debian:bookworm-slim` rootfs that becomes the WSL2 distro.
3. **WSL2 Linux** — Isolated Debian environment with systemd, bubblewrap (for Claude's `/sandbox`), socat, and fzf.
4. **Project Bridge** — `drvfs` mounts connect Windows project folders into Linux on demand with read-write or read-only access.

### Key Files

| File | Role |
|------|------|
| `src/sandbox-config.ps1` | All user-editable config: paths, passwords, container runtime, package list, distro name |
| `src/Install-ClaudeSandbox.ps1` | Main installer — reads config, calls container runtime, invokes WSL, deploys everything |
| `src/common.ps1` | Shared PowerShell helpers: `Execute-InSandbox`, `Write-Step/Ok/Info`, `Check-ExitCode` |
| `src/wsl.conf` | WSL2 config template embedded into the distro (systemd, GPU, no Windows interop) |
| `src/workflows/default.ps1` | Deploys `workflow.sh` into the sandbox; replaces `__WINDOWS_PROJECTS_PATH__` token |
| `src/workflows/default.sh` | Bash functions (`index-projects`, `mount-project`, `switch-project`) with tab completion |
| `src/bashrc/pretty.sh` | Enhanced bashrc with colored prompt and archive extractor utility |
| `docs/setup-commands.md` | Step-by-step manual setup guide and troubleshooting reference |

### Configuration

Edit `src/sandbox-config.ps1` before running the installer. Key variables:

- `$ProjectsPath` — Windows root for projects (mounted into Linux)
- `$ClaudePersistenceDir` — Windows folder where `.claude` state is persisted across distro rebuilds
- `$ContainerRuntime` — `podman` or `docker`
- `$Packages` — Extra apt packages to install in the distro

### Token Replacement Pattern

Workflow scripts use `__TOKEN__` placeholders (e.g., `__WINDOWS_PROJECTS_PATH__`) that `default.ps1` replaces with actual Windows paths before deploying into the sandbox. This avoids hardcoding Windows paths in shell scripts.

### Persistence

Claude Code's `.claude` directory is bind-mounted from a Windows folder (`$ClaudePersistenceDir`) so Claude state, settings, and memory survive distro rebuilds.
