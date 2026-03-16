# Setup Commands


## Install WSL and add distro
```powershell
wsl --install --no-distribution
wsl --set-default-version 2
```

## Create WSL Distro
```powershell
# Create a container with the desired base image
$CONTAINER_ID = podman create debian:bookworm-slim

# Export the container's filesystem to a tarball
podman export $CONTAINER_ID --output="C:\temp\claude-sandbox.tar"

# Clean up the container
podman rm $CONTAINER_ID

# Create a directory for the WSL distro and import the tarball
New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\WSL\claude-sandbox"

# Import the tarball into WSL as a new distro named "claude-sandbox"
wsl --import claude-sandbox "$env:LOCALAPPDATA\WSL\claude-sandbox" "C:\temp\claude-sandbox.tar" --version 2

# Verify the new distro is listed
wsl -l -v  

# Enter WSL as root
wsl -d claude-sandbox -u root 
```

## Setup the WSL distro
```console
# apt update
# apt upgrade
# apt install -y sudo curl nano bubblewrap socat
# useradd -m -s /bin/bash atcomdev
# usermod -aG sudo atcomdev
# passwd atcomdev ## add password
# cat > /etc/wsl.conf << 'WSLEOF'
[boot]
systemd = true

[network]
hostname = claude-sandbox

[automount]
enabled = false
defaultUid = 1000
defaultGid = 1000

[interop]
appendWindowsPath = false

[user]
default = atcomdev
WSLEOF

# exit
```

## Restart WSL
```powershell
wsl --terminate claude-sandbox
wsl -d claude-sandbox
```

## Install Claude
```console 
$ echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
$ curl -fsSL https://claude.ai/install.sh | bash
```

There's a reported bug where /sandbox returns "unsupported" on some WSL 2 setups even though bubblewrap is installed. This happens when the WSL 2 kernel is missing user namespaces support — which is rare on recent Windows builds but worth knowing. If you hit it, check:

```console 
$ cat /proc/sys/kernel/unprivileged_userns_clone # Should return 1 (enabled) If it returns 0, run:
$ echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
$ sudo sysctl --system
```



# Edit bashrc
Edit your ~/.bashrc to source the netvolution bashrc extension. You can also add multiple entries in a `.bashrc.d` directory if you want to keep things organized.
```bash
[ -f "$HOME/.bashrc.d/netvolution.sh" ] && source "$HOME/.bashrc.d/netvolution.sh"

# uncomment to add multiple entries in bashrc 
# if [ -d "$HOME/.bashrc.d" ]; then
#     for f in "$HOME/.bashrc.d"/*.sh; do
#         [ -f "$f" ] && source "$f"
#     done
# fi
```

Then create the netvolution bashrc extension file:
```console
$ mkdir ./.bashrc.d
$ echo '# Netvolution bashrc extension' > ./.bashrc.d/netvolution.sh
$ source ./.bashrc.d/netvolution.sh
```
Then edit the file and place the contents of `netvolution.sh` in that file.
This will add the `switch-project` shell command

