# claude-sandbox

Automates the creation of an isolated WSL2 Debian sandbox pre-configured with Claude Code CLI. Targets Windows developers who want a clean, reproducible Linux dev environment without polluting their Windows PATH or system.

---

## Prerequisites

- Windows 10/11 with WSL2 feature enabled (or the installer will enable it)
- [Podman for Windows](https://podman.io/getting-started/installation) **or** Docker Desktop installed and in `PATH`
- An elevated (Administrator) PowerShell prompt

---

## Quick Start

1. **Edit** `src/sandbox-config.ps1` to set your paths and preferences.
2. **Run** the installer from an elevated PowerShell prompt:

```powershell
cd src
./Install-ClaudeSandbox.ps1
```

3. **Launch** the sandbox and start coding:

```powershell
wsl -d claude-sandbox
```

```bash
switch-project   # mount a Windows project into the sandbox
claude           # start Claude Code
```

---

## Configuration

Edit `src/sandbox-config.ps1` before running the installer. All tunables live here — do not edit the installer directly.

| Variable | Default | Description |
|---|---|---|
| `$ProjectsPath` | `D:\Projects` | Windows directory containing your projects |
| `$Username` | `atcomdev` | Linux user created inside the distro |
| `$UserPassword` | `changeme` | Password for the Linux user (avoid single quotes) |
| `$DistroName` | `claude-sandbox-test` | Name registered in WSL2 |
| `$ContainerRuntime` | `podman` | `podman` or `docker` |
| `$DistroImage` | `debian:bookworm-slim` | Base container image |
| `$Packages` | see config | APT packages installed inside the distro |

---

## What the Installer Does

| Step | Action |
|---|---|
| 1 | Validates WSL2 feature and container runtime are present |
| 2 | Pulls `debian:bookworm-slim`, exports it as a TAR, imports into WSL2 |
| 3 | Installs APT packages, creates the Linux user, writes `wsl.conf` |
| 4 | Installs Claude Code CLI, deploys `netvolution.sh` bashrc extension, indexes projects |
| 5 | Cleans up temporary files |

---

## Repository Structure

```
src/
├── Install-ClaudeSandbox.ps1   # Main automated installer
├── sandbox-config.ps1          # User-editable configuration (edit before running)
├── wsl.conf                    # WSL2 config template — tokens replaced at install time
└── bashrc/
    └── netvolution.sh          # Bash extension: switch-project + index-projects

docs/
└── setup-commands.md           # Manual step-by-step alternative to the installer

temp/                           # Transient files (TAR export, rendered templates) — gitignored
```

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

## Project Switching

The `switch-project` command (added to `.bashrc` via `netvolution.sh`) mounts a Windows project folder into the sandbox using drvfs.

```bash
switch-project            # interactive picker (fzf or numbered list)
switch-project my-app     # mount a specific project by name
index-projects            # rebuild the project index from D:\Projects
```

- The selected project is mounted **read-write** at `~/current-project`
- `Netvolution6` is kept mounted **read-only** at `~/netvolution6` for reference
- Tab completion is available for project names

---

## Manual Setup

If you prefer to provision the environment step by step, see [`docs/setup-commands.md`](docs/setup-commands.md).

---

## Known Issues

**`/sandbox` reports "unsupported"**

Occurs when the WSL2 kernel is missing user namespace support. Fix:

```bash
sudo sysctl -w kernel.unprivileged_userns_clone=1
```

To persist across reboots:

```bash
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

---

## External Dependencies

- Container registry reachable to pull `debian:bookworm-slim`
- `https://claude.ai/install.sh` — Claude Code CLI installer
