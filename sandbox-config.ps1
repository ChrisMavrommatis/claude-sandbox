# ═══════════════════════════════════════════════════════════════════════════════
# Claude Sandbox — Configuration
# Edit this file. 
# The following files read it automatically.
# - Install-ClaudeSandbox.ps1 
# ═══════════════════════════════════════════════════════════════════════════════

# -- Paths & credentials --------------------------------------------------------
$ProjectsPath = "D:\Projects"   # Root folder containing your Windows projects
$UserPassword = "changeme"      # Avoid single-quote characters in the password

# -- Container runtime --------------------------------------------------------- 
$ContainerRuntime = "podman"    # "podman" or "docker"

# -- Packages to install inside the sandbox ------------------------------------
$Packages = @(
    "sudo"          # Required for running commands as root inside the sandbox
    "curl"          # Required for install scripts and general use
    "nano"          # Simple terminal text editor 
    "bubblewrap"    # Required for Claude Code /sandbox
    "socat"         # Required for Claude Code network features
    "fzf"           # Interactive project picker for switch-project
)

# -- Distro settings (unlikely to need changing) ------------------------------
$Username   = "atcomdev"
$DistroName = "claude-sandbox-test"
$DistroImage = "debian:bookworm-slim"
