# ═══════════════════════════════════════════════════════════════════════════════
# Claude Sandbox - Configuration
# Edit this file. 
# The following files read it automatically.
# - Install-ClaudeSandbox.ps1
# - Uninstall-ClaudeSandbox.ps1
# - Verify-ClaudeSandbox.ps1
# - Update-ClaudeSandbox.ps1
# - Change-Profile.ps1
# - Change-Workflow.ps1
# ═══════════════════════════════════════════════════════════════════════════════

# -- Paths & credentials --------------------------------------------------------
$ProjectsPath           = "D:\Projects"   # Root folder containing your Windows projects
# Leave blank to be prompted during install (recommended).
# Set a value here only for non-interactive / CI runs. Avoid single-quote characters.
$UserPassword           = ""
$ClaudePersistenceDir   = "D:\.claude"    # Windows folder to be mounted as /.claude in the sandbox for persistent storage

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
$Username               = "dev"
$DistroName             = "claude-sandbox-test"
$DistroImage            = "debian:bookworm-slim"
$InstallDir             = "D:\WSL\$DistroName"

# -- Terminal profile settings ------------------------------------------------------
$TerminalProfileName        = "Claude Sandbox Test"  # Name shown in Windows Terminal dropdown
$TerminalProfileIcon        = "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png"  # Optional: Path to custom icon for Windows Terminal profile (must be .png)
$TerminalProfileColorScheme = "One Half Dark"  # Optional: Color scheme for Windows Terminal profile (must be defined in your settings.json)
$TerminalProfileBackground  = "#1a0a22"  # Optional: Background color for Windows Terminal profile (hex code)

# -- Security settings --------------------------------------------------------
$GpuEnabled                 = $false  # Enable GPU passthrough (only if you need it)




