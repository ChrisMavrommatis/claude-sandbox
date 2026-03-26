# Claude Sandbox

A one-command setup that creates an isolated Linux environment on Windows (via WSL2) purpose-built for [Claude Code](https://claude.ai/code). Your Windows projects stay on Windows - the sandbox mounts them on demand so Claude can work on them without touching the rest of your system.

## What you get

- A clean Debian Linux distro running inside WSL2
- Claude Code installed and ready to go
- A `switch-project` command with tab completion to jump into any of your Windows projects
- Claude's state and settings persisted across distro rebuilds (no re-authentication)
- Full support for Claude's sandbox mode and network features (bubblewrap + socat)

## Prerequisites

- Windows 10/11 with WSL2 enabled (`wsl --install --no-distribution`)
- [Podman for Windows](https://podman.io) or Docker Desktop
- PowerShell (run as Administrator)

## Quick Start

**1. Edit the config** - open `sandbox-config.ps1` and set your paths:

```powershell
$ProjectsPath         = "D:\Projects"  # where your Windows projects live
$ClaudePersistenceDir = "D:\.claude"   # where Claude state is persisted
$UserPassword         = "yourpassword"
$ContainerRuntime     = "podman"       # or "docker"
```

**2. Run the installer** from an elevated PowerShell prompt:

```powershell
.\Install-ClaudeSandbox.ps1
```

That's it. The installer creates the WSL2 distro, installs packages, configures Claude Code, and wires up project mounting and persistence.

## Using the sandbox

Once inside the WSL2 distro:

```bash
# Index your Windows projects (run once after install, or after adding new folders)
index-projects

# Jump into a project - opens fzf picker if no name given, tab completion otherwise
switch-project
switch-project my-app

# Or mount manually
mount-project my-app --rw    # read-write
mount-project my-app --ro    # read-only
unmount-project my-app
```

## Verifying the installation

After installing (or any time you want to check the sandbox is healthy):

```powershell
.\Verify-ClaudeSandbox.ps1
```

Runs 26 checks across installation and security, each identified by a code (`I-001` for installation, `S-001` for security). Example output:

```
  PASS [I-001] Distro registered
  PASS [I-002] User 'dev' exists
  PASS [S-001] Windows interop disabled
  WARN [I-012] Claude Code not installed
  ------------------------------------------------------------
  All checks passed: 22 passed, 1 warnings
```

## Management

```powershell
.\Change-Profile.ps1              # pick a bashrc style (default or pretty)
.\Change-Workflow.ps1             # pick a workflow profile
.\Update-ClaudeSandbox.ps1        # update packages and re-deploy profiles
.\Uninstall-ClaudeSandbox.ps1     # remove the distro (keeps Claude persistence data)
```

## Windows Terminal integration

The installer automatically adds a Windows Terminal profile. Customise it in `sandbox-config.ps1` before running the installer:

```powershell
$TerminalProfileName        = "Claude Sandbox"
$TerminalProfileIcon        = "ms-appx:///..."
$TerminalProfileColorScheme = "One Half Dark"
$TerminalProfileBackground  = "#1a0a22"
```

To manage the Terminal profile independently, use `Add-TerminalProfile` or `Remove-TerminalProfile` from the `ClaudeSandbox` module.

## How it works

The installer exports a `debian:bookworm-slim` container image as a WSL2 tarball, imports it as a distro, then configures it from scratch. Windows project folders are mounted into Linux on demand using WSL's `drvfs` driver - no copying, no syncing. Claude's `.claude` directory is permanently bind-mounted from a Windows folder via `/etc/fstab` so your login, memory, and settings survive even if you nuke and rebuild the distro.

## Troubleshooting

**Claude sandbox mode returns "unsupported"** - the WSL2 kernel may have user namespaces disabled. Fix:

```bash
cat /proc/sys/kernel/unprivileged_userns_clone   # should be 1
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```
