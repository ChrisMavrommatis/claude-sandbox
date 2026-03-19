# Manual Setup Guide

Step-by-step commands to build the Claude Sandbox from scratch without the installer script. Useful for understanding what the installer does, troubleshooting, or customising the setup.

All PowerShell commands run from an **elevated** (Administrator) prompt on the Windows host. Adjust paths and names to match your `sandbox-config.ps1` values.

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

# Import the tarball as a new WSL distro
New-Item -ItemType Directory -Force -Path "D:\WSL\claude-sandbox"
wsl --import claude-sandbox "D:\WSL\claude-sandbox" "C:\temp\claude-sandbox.tar" --version 2

# Verify
wsl -l -v
```

---

## 3. Configure the Distro (as root)

```powershell
wsl -d claude-sandbox -u root
```

Inside WSL as root:

```bash
# Update and install required packages
apt update && apt upgrade -y
apt install -y sudo curl nano bubblewrap socat fzf

# Create user
useradd -m -s /bin/bash dev
usermod -aG sudo dev
passwd dev

# Write wsl.conf
cat > /etc/wsl.conf << 'EOF'
[boot]
systemd = true
protectBinfmt = true

[automount]
enabled = false
mountFsTab = true
root = /mnt/
uid = 1000
gid = 1000

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
enabled = true

[time]
useWindowsTimezone = true
EOF

exit
```

---

## 4. Restart the Distro

```powershell
wsl --terminate claude-sandbox
# Wait a few seconds, then re-enter as the default user
wsl -d claude-sandbox
```

---

## 5. Install Claude Code (as user)

```bash
# Add ~/.local/bin to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash
```

---

## 6. Set Up Claude Persistence

This mounts a Windows folder as `~/.claude` so your Claude login, settings, and memory survive distro rebuilds.

```bash
# Create the mount point
mkdir -p ~/.claude
```

Then as root, add the fstab entry (replace `D:\.claude` with your actual Windows path):

```bash
echo 'D:\.claude /home/dev/.claude drvfs uid=1000,gid=1000,umask=022,metadata 0 0' | sudo tee -a /etc/fstab

# Symlink .claude.json so it's also persisted
ln -sf ~/.claude/.claude.json ~/.claude.json
```

Restart to apply fstab:

```powershell
wsl --terminate claude-sandbox
wsl -d claude-sandbox
```

---

## 7. Deploy the Bashrc Profile

The profile replaces `~/.bashrc`. Copy `src/profiles/default.sh` from the repo into the distro:

```powershell
Copy-Item ".\src\profiles\default.sh" "\\wsl$\claude-sandbox\home\dev\.bashrc"
```

Or manually ensure `~/.bashrc` ends with:

```bash
export PATH="$HOME/.local/bin:$PATH"

# Load workflow
[ -f "$HOME/.bashrc.d/workflow.sh" ] && source "$HOME/.bashrc.d/workflow.sh"
```

---

## 8. Deploy the Workflow

The workflow provides `index-projects`, `mount-project`, `switch-project`, and the welcome banner.

```powershell
# Create the .bashrc.d directory
wsl -d claude-sandbox -u dev -- bash -c "mkdir -p ~/.bashrc.d"

# Copy and patch the workflow (replace the token with your Windows projects path)
(Get-Content ".\src\workflows\default.sh" -Raw) `
    -replace "__PROJECTS_DRVFS__", "D:\\Projects" |
    Set-Content -NoNewline "\\wsl$\claude-sandbox\home\dev\.bashrc.d\workflow.sh"
```

---

## 9. Verify

```bash
# Reload shell
source ~/.bashrc

# Should print the welcome banner and Claude version
# Test project commands
index-projects
switch-project <tab>
```

---

## 10. Add a Windows Terminal Profile (optional)

The installer does this automatically, but you can run it manually or re-apply it any time:

```powershell
.\src\Add-TerminalProfile.ps1
```

This reads `$TerminalProfileName`, `$TerminalProfileIcon`, `$TerminalProfileColorScheme`, and `$TerminalProfileBackground` from `sandbox-config.ps1` and patches the Windows Terminal fragment file for the distro as well as the main `settings.json` dropdown list.

To remove the profile entry:

```powershell
.\src\Remove-TerminalProfile.ps1
```

---


## Troubleshooting

**Claude sandbox mode returns "unsupported"** — user namespaces may be disabled in the WSL2 kernel:

```bash
cat /proc/sys/kernel/unprivileged_userns_clone   # should be 1

# If 0:
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

**Mount fails on `index-projects`** — check that `PROJECTS_DRVFS` in `~/.bashrc.d/workflow.sh` matches your actual Windows projects path.

**Claude not found after install** — ensure `~/.local/bin` is on your PATH (`echo $PATH`) and that the install completed without errors.
