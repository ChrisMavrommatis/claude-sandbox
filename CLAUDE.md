# CLAUDE.md

## Project Overview

This repository automates the setup of an isolated WSL2 Debian sandbox pre-configured with Claude Code CLI. It targets Windows developers who want a clean, reproducible Linux dev environment without polluting their Windows PATH.

**Primary script:** `src/Install-ClaudeSandbox.ps1` — run once from an elevated PowerShell prompt to provision the full environment.

---

## Repository Structure

```
src/
├── Install-ClaudeSandbox.ps1   # Main automated installer (PowerShell)
├── sandbox-config.ps1          # User-editable configuration (edit before running)
├── wsl.conf                    # WSL2 config template (tokens replaced at install time)
└── bashrc/
    └── netvolution.sh          # Bash extension: switch-project + index-projects

docs/
└── setup-commands.md           # Manual step-by-step alternative to the installer

temp/                           # Transient: exported TAR + rendered templates (gitignored)
```

> `Apply-BashrcExtension.ps1` is currently being rewritten — do not reference or modify it.

---

## Configuration

Edit `src/sandbox-config.ps1` before running the installer.

| Variable | Default | Description |
|---|---|---|
| `$ProjectsPath` | `D:\Projects` | Windows directory mounted into WSL |
| `$Username` | `atcomdev` | Linux user created inside the distro |
| `$UserPassword` | `changeme` | Password for the Linux user |
| `$DistroName` | `claude-sandbox-test` | Name of the WSL2 distro |
| `$ContainerRuntime` | `podman` | `podman` or `docker` |
| `$DistroImage` | `debian:bookworm-slim` | Base container image |
| `$Packages` | see config | APT packages installed inside the distro |

---

## Installation

```powershell
# Run from elevated PowerShell inside the src/ directory
./Install-ClaudeSandbox.ps1
```

**What the installer does:**
1. Validates WSL2 feature and container runtime
2. Pulls `$DistroImage`, exports it as a TAR, imports into WSL2 as `$DistroName`
3. Installs APT packages, creates `$Username`, writes `wsl.conf`
4. Installs Claude Code CLI, deploys `netvolution.sh`, indexes projects
5. Cleans up temp files

---

## Templates and Token Substitution

Two files contain placeholder tokens replaced at install time:

| File | Tokens |
|---|---|
| `src/wsl.conf` | `__DistroName__`, `__Username__` |
| `src/bashrc/netvolution.sh` | `__PROJECTS_DRVFS__`, `__NETVOLUTION6_DRVFS__` |

Rendered copies are written to `temp/` then copied into the distro via `\\wsl$\`. Do not commit rendered files.

---

## Packages Installed in the Distro

| Package | Purpose |
|---|---|
| `sudo` | Privilege escalation inside the sandbox |
| `curl` | Required by install scripts |
| `nano` | Terminal text editor |
| `bubblewrap` | Required for Claude Code `/sandbox` |
| `socat` | Required for Claude Code network features |
| `fzf` | Interactive project picker for `switch-project` |

---

## Project Mounting (netvolution.sh)

`src/bashrc/netvolution.sh` is deployed to `~/.bashrc.d/netvolution.sh` inside the distro and sourced from `.bashrc`. It provides:

- **`index-projects`** — mounts `$ProjectsPath` (ro, temporarily), lists subdirectories into `~/.cache/projects-index`, then unmounts
- **`switch-project [name]`** — unmounts the current project, mounts the selected one rw at `~/current-project`, keeps Netvolution6 mounted ro at `~/netvolution6`; uses `fzf` if available, else a numbered list
- **Tab completion** for `switch-project` backed by the projects index

drvfs mount options used: `uid=1000,gid=1000,umask=022` (ro for index/Netvolution6, `metadata` for rw project mount).

---

## Conventions

- PowerShell scripts use `#Requires -Version 5.1` and a `.SYNOPSIS`/`.DESCRIPTION` comment block.
- Configuration is always separated from logic — edit `sandbox-config.ps1`, not the installer.
- The installer dot-sources `sandbox-config.ps1` at runtime.
- Bash scripts inside the distro use `set -e` for fail-fast behavior.
- Line endings: the installer explicitly converts `\r\n` → `\n` before writing files into WSL.
- No CI/CD — this is a one-time local setup tool.

---

## Known Issues

**WSL2 kernel missing user namespace support**

Affects the Claude Code `/sandbox` command. Fix:

```bash
sudo sysctl -w kernel.unprivileged_userns_clone=1
# To persist:
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

---

## External Dependencies

- Container registry (to pull `debian:bookworm-slim`)
- `https://claude.ai/install.sh` (Claude Code CLI installer)
