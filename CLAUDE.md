# CLAUDE.md

## Project Overview

This repository automates the setup of an isolated WSL2 Debian sandbox pre-configured with Claude Code CLI. It targets Windows developers who want a clean, reproducible Linux dev environment without polluting their Windows PATH.

**Primary script:** `Install-ClaudeSandbox.ps1` — run once from an elevated PowerShell prompt to provision the full environment.

## Repository Structure

```
├── Install-ClaudeSandbox.ps1   # Main automated installer (PowerShell)
├── sandbox-config.ps1          # User-editable configuration (edit before running)
├── wsl.conf                    # WSL2 config template (copied into distro)
├── setup-commands.md           # Manual step-by-step alternative to the installer
└── README.md                   # Minimal intro
```

## Configuration

Edit `sandbox-config.ps1` before running the installer:

| Variable | Default | Description |
|---|---|---|
| `$ProjectsPath` | `D:\Projects` | Windows directory mounted into WSL |
| `$Username` | `atcomdev` | Linux user created inside the distro |
| `$UserPassword` | `changeme` | Password for the Linux user |
| `$DistroName` | `claude-sandbox` | Name of the WSL2 distro |
| `$ContainerRuntime` | `podman` | `podman` or `docker` |
| `$DistroImage` | `debian:bookworm-slim` | Base container image |

## Installation

```powershell
# Run from elevated PowerShell
./Install-ClaudeSandbox.ps1
```

**What it does:**
1. Validates WSL2 and container runtime (Podman or Docker)
2. Pulls `debian:bookworm-slim` and exports it as a TAR
3. Imports the TAR into WSL2 as a new named distro
4. Runs a root setup script (installs packages, creates user)
5. Runs a user setup script (configures bashrc, directories)
6. Installs Claude Code CLI

## Packages Installed in the Distro

- `sudo`, `curl`, `nano` — essentials
- `bubblewrap` — required for Claude Code `/sandbox`
- `socat` — required for Claude Code network features
- `fzf` — optional interactive project picker

## Project Mounting

Windows projects are mounted into the distro via drvfs. The installer maps `$ProjectsPath` (e.g. `D:\Projects`) to a path inside WSL (e.g. `/mnt/d/Projects`). The `switch-project` bash function (added to `.bashrc`) lets the user switch the active project mount.

## Known Issues

**WSL2 kernel missing user namespace support:**
Affects the Claude Code `/sandbox` command. Fix by enabling unprivileged user namespaces inside WSL:
```bash
sudo sysctl -w kernel.unprivileged_userns_clone=1
```
To persist across reboots, add it to `/etc/sysctl.conf`.

## Conventions

- PowerShell scripts use `#Requires -Version 5.1` and a `.SYNOPSIS`/`.DESCRIPTION` comment block.
- Configuration is always separated from logic — edit `sandbox-config.ps1`, not the installer.
- The installer sources `sandbox-config.ps1` at runtime; keep all tunables there.
- Bash scripts inside the distro use `set -e` for fail-fast behavior.
- No CI/CD — this is a one-time local setup tool.

## External Dependencies

- Container registry (to pull `debian:bookworm-slim`)
- `https://claude.ai/install.sh` (Claude Code CLI installer)
