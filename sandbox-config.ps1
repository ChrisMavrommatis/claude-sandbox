# ═══════════════════════════════════════════════════════════════════════════════
# Claude Sandbox - Configuration
# Edit this file.
# The following files read it automatically and use $Config directly.
# - Install-ClaudeSandbox.ps1
# - Uninstall-ClaudeSandbox.ps1
# - Verify-ClaudeSandbox.ps1
# - Change-Profile.ps1
# - Change-Workflow.ps1
# - Change-Policy.ps1
# ═══════════════════════════════════════════════════════════════════════════════

$Config = @{

    # -- Paths & credentials --------------------------------------------------------
    ProjectsPath           = "D:\Projects"   # Root folder containing your Windows projects
    UserPassword           = "changeme"      # Avoid single-quote characters in the password
    ClaudePersistenceDir   = "D:\.claude"    # Windows folder to be mounted as /.claude in the sandbox for persistent storage

    # -- Container runtime ----------------------------------------------------------
    ContainerRuntime = "podman"    # "podman" or "docker"

    # -- Packages to install inside the sandbox -------------------------------------
    Packages = @(
        "sudo"          # Required for running commands as root inside the sandbox
        "curl"          # Required for install scripts and general use
        "nano"          # Simple terminal text editor
        "bubblewrap"    # Required for Claude Code /sandbox
        "socat"         # Required for Claude Code network features
        "fzf"           # Interactive project picker for switch-project
    )

    # -- Distro settings (unlikely to need changing) --------------------------------
    Username    = "dev"
    DistroName  = "claude-sandbox"
    DistroImage = "debian:bookworm-slim"
    InstallDir  = "D:\WSL\claude-sandbox"  # Update this if you change DistroName

    # -- Terminal profile settings --------------------------------------------------
    TerminalProfileName        = "Claude Sandbox"  # Name shown in Windows Terminal dropdown
    TerminalProfileIcon        = "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png"  # Optional: path to .png icon
    TerminalProfileColorScheme = "One Half Dark"        # Optional: must exist in your Windows Terminal settings.json
    TerminalProfileBackground  = "#1a0a22"              # Optional: hex background color

    # -- Security settings ----------------------------------------------------------
    GpuEnabled     = $false  # Enable GPU passthrough (only if you need it)
    SessionTimeout = 0       # Idle shell timeout in seconds (0 = disabled)

}
