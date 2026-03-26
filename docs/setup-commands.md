# Manual Setup Guide

Step-by-step commands to build the Claude Sandbox without the installer. Useful for understanding what the installer does, troubleshooting, or customising the setup.

All PowerShell commands run from an **elevated** (Administrator) prompt. Adjust paths and names to match your `sandbox-config.ps1` values.

---

## 1. Enable WSL2

```powershell
wsl --install --no-distribution
wsl --set-default-version 2
```

---

## 2. Create the WSL Distro

```powershell
# Export a debian:bookworm-slim container as a tarball
$ContainerId = podman create debian:bookworm-slim
podman export $ContainerId --output="C:\temp\claude-sandbox.tar"
podman rm $ContainerId

# Import as a WSL distro
New-Item -ItemType Directory -Force -Path "D:\WSL\claude-sandbox"
wsl --import claude-sandbox "D:\WSL\claude-sandbox" "C:\temp\claude-sandbox.tar" --version 2

# Verify
wsl -l -v
```

---

## 3. Configure the Distro

```powershell
wsl -d claude-sandbox -u root
```

Inside WSL as root:

```bash
# Update and install packages
apt update && apt upgrade -y
apt install -y sudo curl nano bubblewrap socat fzf

# Create user
useradd -m -s /bin/bash dev
usermod -aG sudo dev
passwd dev

# Configure sudo password feedback
echo 'Defaults pwfeedback' > /etc/sudoers.d/pwfeedback
chmod 0440 /etc/sudoers.d/pwfeedback

# Write wsl.conf (gpu enabled = false by default, change if needed)
cat > /etc/wsl.conf << 'EOF'
[boot]
systemd = true
protectBinfmt = true

[automount]
enabled = false
mountFsTab = true
root = /mnt/

[network]
hostname = claude-sandbox
generateHosts = true
generateResolvConf = true

[interop]
enabled = false
appendWindowsPath = false

[user]
default = dev

[gpu]
enabled = false

[time]
useWindowsTimezone = true
EOF

exit
```

---

## 4. Restart the Distro

```powershell
wsl --terminate claude-sandbox
# Wait a few seconds, then re-enter
wsl -d claude-sandbox
```

---

## 5. Set Up Claude Persistence

Mounts a Windows folder as `~/.claude` so login, settings, and memory survive distro rebuilds.

```bash
mkdir -p ~/.claude

# Add fstab entry (replace D:\.claude with your path, use your actual uid/gid)
echo "D:\.claude /home/dev/.claude drvfs uid=$(id -u),gid=$(id -g),umask=022,metadata 0 0" | sudo tee -a /etc/fstab

# Symlink .claude.json for persistence
ln -sf ~/.claude/.claude.json ~/.claude.json
```

Restart to apply fstab:

```powershell
wsl --terminate claude-sandbox
wsl -d claude-sandbox
```

---

## 6. Install Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

---

## 7. Create Directories

```bash
mkdir -p ~/projects
mkdir -p ~/.bashrc.d
```

---

## 8. Deploy the Bashrc Profile

Copy `ClaudeSandbox/Assets/profiles/default.sh` from the repo (this replaces `~/.bashrc` entirely and includes PATH, umask, and workflow sourcing):

```powershell
Copy-Item ".\ClaudeSandbox\Assets\profiles\default.sh" "\\wsl$\claude-sandbox\home\dev\.bashrc"
```

---

## 9. Deploy the Workflow

```powershell
# Copy and patch the workflow (replace token with your Windows projects path)
(Get-Content ".\ClaudeSandbox\Assets\workflows\default.sh" -Raw) `
    -replace "__PROJECTS_DRVFS__", "D:\\Projects" |
    Set-Content -NoNewline "\\wsl$\claude-sandbox\home\dev\.bashrc.d\workflow.sh"
```

---

## 10. Verify

```bash
source ~/.bashrc

# Should print the welcome banner
index-projects
switch-project <tab>
```

Or from PowerShell:

```powershell
.\Verify-ClaudeSandbox.ps1
```

---

## 11. Windows Terminal Profile (optional)

```powershell
Import-Module .\ClaudeSandbox\ClaudeSandbox.psd1 -Force
. .\sandbox-config.ps1
$Config = @{
    DistroName = $DistroName
    TerminalProfileName = $TerminalProfileName
    TerminalProfileIcon = $TerminalProfileIcon
    TerminalProfileColorScheme = $TerminalProfileColorScheme
    TerminalProfileBackground = $TerminalProfileBackground
}
Add-TerminalProfile -Config $Config
```

---

## Troubleshooting

**Claude sandbox mode returns "unsupported"** - user namespaces may be disabled:

```bash
cat /proc/sys/kernel/unprivileged_userns_clone   # should be 1

# If 0:
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

**Mount fails on `index-projects`** - check that `PROJECTS_DRVFS` in `~/.bashrc.d/workflow.sh` matches your actual Windows projects path.

**Claude not found after install** - ensure `~/.local/bin` is on your PATH (`echo $PATH`).
