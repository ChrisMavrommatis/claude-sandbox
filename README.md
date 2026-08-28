# Claude Sandbox

![WSL2](https://img.shields.io/badge/platform-WSL2-0078D4?logo=windows)
![PowerShell](https://img.shields.io/badge/shell-PowerShell-5391FE?logo=powershell)

> **Unmaintained as of August 2026.** This is Windows-only and I no longer work on Windows, so I cannot
> test changes. It worked when I last ran it, in April 2026, against the versions of WSL2, Podman and
> Claude Code current then. It pins an external world it does not control - a Debian image digest, Podman
> for Windows, and Claude Code's own installer - so assume parts of it have drifted.
>
> The reasoning is the part I would still stand behind: the [threat model](docs/threat-model.md) and the
> [decision records](docs/decisions/) explain what this is defending against and why each choice was made.
> Those do not go stale the way the scripts do.
>
> `Test-Sandbox` runs 22 security checks and 15 installation checks, two of which expand at runtime - one
> per required package, one per credential-guard fixture - so a typical run reports 45 results.
> **Nothing runs them in CI**, so a passing count is something you get by running it, not something this
> page can promise you.

A one-command setup that creates an isolated Linux environment on Windows (via WSL2) purpose-built for [Claude Code](https://claude.ai/code).
Your Windows projects stay on Windows - the sandbox mounts them on demand so Claude can work on them without touching the rest of your system.

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
$ContainerRuntime     = "podman"       # or "docker"
```

**2. Run the installer** from an elevated PowerShell prompt:

```powershell
.\Install-ClaudeSandbox.ps1
```

The installer walks you through an interactive wizard - every setting has a default from the config file, so you can press Enter to accept or type a new value.
The password is always prompted securely (never stored in the config).

For unattended installs, set `$UserPassword` in the config and use:

```powershell
.\Install-ClaudeSandbox.ps1 -NonInteractive
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

Each check is identified by a code (`I-001` for installation, `S-001` for security). Example output:

```text
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
.\Change-Policy.ps1               # pick a managed policy (default, restrictive, or maximum)
.\Verify-ClaudeSandbox.ps1        # verify installation and security posture
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

## Security

- See [docs/about.md](docs/about.md) for what the sandbox does and does not protect against.
- See [docs/threat-model.md](docs/threat-model.md) for the full threat model.
- See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Troubleshooting

**Claude sandbox mode returns "unsupported"** - the WSL2 kernel may have user namespaces disabled. Fix:

```bash
cat /proc/sys/kernel/unprivileged_userns_clone   # should be 1
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```
