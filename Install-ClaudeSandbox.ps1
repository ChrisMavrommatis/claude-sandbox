#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the Claude Code WSL2 sandbox environment.
.DESCRIPTION
    Creates a Debian bookworm-slim WSL2 distro with Claude Code installed
    and project-switching helpers configured.

    By default, runs an interactive wizard that prompts for every setting
    using values from sandbox-config.ps1 as defaults. The password is
    always prompted securely and never read from the config file.

    Use -NonInteractive to skip the wizard and use config values as-is
    (requires $UserPassword to be set in sandbox-config.ps1).

    For fully automated installs, import the ClaudeSandbox module directly
    and call Install-Sandbox with a populated $Config hashtable.
.PARAMETER NonInteractive
    Skip the install wizard and use values from sandbox-config.ps1 as-is.
    Requires $UserPassword to be set in the config file.
#>
param(
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\ClaudeSandbox\ClaudeSandbox.psd1" -Force
. "$PSScriptRoot\sandbox-config.ps1"

$Config = @{
    DistroName                 = $DistroName
    DistroImage                = $DistroImage
    Username                   = $Username
    UserPassword               = $UserPassword
    ProjectsPath               = $ProjectsPath
    ClaudePersistenceDir       = $ClaudePersistenceDir
    ContainerRuntime           = $ContainerRuntime
    Packages                   = $Packages
    InstallDir                 = $InstallDir
    TerminalProfileName        = $TerminalProfileName
    TerminalProfileIcon        = $TerminalProfileIcon
    TerminalProfileColorScheme = $TerminalProfileColorScheme
    TerminalProfileBackground  = $TerminalProfileBackground
    GpuEnabled                 = $GpuEnabled
}

# -- Install Wizard --------------------------------------------------------------------
if (-not $NonInteractive) {
    Write-Host ""
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    Write-Host "  Claude Sandbox - Install Wizard" -ForegroundColor White
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Configure your sandbox. Press Enter to accept [defaults]." -ForegroundColor DarkGray
    Write-Host ""

    function Read-Default([string]$Prompt, [string]$Default, [string[]]$ValidValues) {
        if ($Default) {
            $input = Read-Host -Prompt "  $Prompt [$Default]"
        } else {
            $input = Read-Host -Prompt "  $Prompt"
        }
        $result = if ([string]::IsNullOrWhiteSpace($input)) { $Default } else { $input.Trim() }
        if ($ValidValues -and $result -notin $ValidValues) {
            Write-Host "     Invalid value '$result'. Must be one of: $($ValidValues -join ', ')" -ForegroundColor Yellow
            return Read-Default -Prompt $Prompt -Default $Default -ValidValues $ValidValues
        }
        return $result
    }

    function Read-Secure([string]$Prompt) {
        $secure = Read-Host -Prompt "  $Prompt" -AsSecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        )
    }

    # -- Identity --
    Write-Host "  -- Identity --" -ForegroundColor DarkCyan
    $Config.DistroName = Read-Default "Distro name" $Config.DistroName
    $Config.Username   = Read-Default "Username" $Config.Username

    # Password - always prompt interactively, never show a default [S-013]
    while ($true) {
        $pw = Read-Secure "Set password"
        if ([string]::IsNullOrEmpty($pw)) {
            Write-Host "     Password cannot be empty." -ForegroundColor Yellow
            continue
        }
        $pwConfirm = Read-Secure "Confirm password"
        if ($pw -ne $pwConfirm) {
            Write-Host "     Passwords do not match. Try again." -ForegroundColor Yellow
            continue
        }
        $Config.UserPassword = $pw
        $pw = $null
        $pwConfirm = $null
        break
    }
    Write-Host ""

    # -- Paths --
    Write-Host "  -- Paths --" -ForegroundColor DarkCyan
    $Config.ProjectsPath        = Read-Default "Projects path (Windows)" $Config.ProjectsPath
    $Config.ClaudePersistenceDir = Read-Default "Persistence dir (Windows)" $Config.ClaudePersistenceDir

    # Recalculate InstallDir default if distro name changed
    $defaultInstallDir = $Config.InstallDir
    if ($defaultInstallDir -match '\\[^\\]+$') {
        $parentDir = Split-Path $defaultInstallDir -Parent
        $defaultInstallDir = Join-Path $parentDir $Config.DistroName
    }
    $Config.InstallDir = Read-Default "Install directory (Windows)" $defaultInstallDir
    Write-Host ""

    # -- Runtime --
    Write-Host "  -- Runtime --" -ForegroundColor DarkCyan
    $Config.ContainerRuntime = Read-Default "Container runtime" $Config.ContainerRuntime @("podman", "docker")
    $Config.DistroImage      = Read-Default "Base image" $Config.DistroImage

    $gpuDefault = if ($Config.GpuEnabled) { "Y" } else { "N" }
    $gpuInput   = Read-Default "Enable GPU passthrough (Y/N)" $gpuDefault @("Y", "N", "y", "n")
    $Config.GpuEnabled = $gpuInput -match '^[Yy]$'
    Write-Host ""

    # -- Terminal --
    Write-Host "  -- Windows Terminal --" -ForegroundColor DarkCyan
    $Config.TerminalProfileName = Read-Default "Profile name" $Config.TerminalProfileName
    Write-Host ""

    # -- Summary --
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    Write-Host "  Install Summary" -ForegroundColor White
    Write-Host "  Distro      : $($Config.DistroName)" -ForegroundColor DarkGray
    Write-Host "  User        : $($Config.Username)" -ForegroundColor DarkGray
    Write-Host "  Image       : $($Config.DistroImage)" -ForegroundColor DarkGray
    Write-Host "  Runtime     : $($Config.ContainerRuntime)" -ForegroundColor DarkGray
    Write-Host "  Projects    : $($Config.ProjectsPath)" -ForegroundColor DarkGray
    Write-Host "  Persistence : $($Config.ClaudePersistenceDir)" -ForegroundColor DarkGray
    Write-Host "  InstallDir  : $($Config.InstallDir)" -ForegroundColor DarkGray
    Write-Host "  GPU         : $(if ($Config.GpuEnabled) { 'Yes' } else { 'No' })" -ForegroundColor DarkGray
    Write-Host "  Terminal    : $($Config.TerminalProfileName)" -ForegroundColor DarkGray
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    Write-Host ""

    $proceed = Read-Host "  Proceed with installation? [Y/n]"
    if ($proceed -match '^[Nn]') {
        Write-Host "  Aborted." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}
else {
    # Non-interactive: password must be set in config
    if ([string]::IsNullOrEmpty($Config.UserPassword)) {
        Write-Host ""
        Write-Host "  ERROR: `$UserPassword is empty and -NonInteractive was specified." -ForegroundColor Red
        Write-Host "  Set `$UserPassword in sandbox-config.ps1 or run without -NonInteractive." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    # Warn if password is still default [S-013]
    if ($Config.UserPassword -eq "changeme") {
        Write-Host ""
        Write-Host "  WARNING: Password is still 'changeme'." -ForegroundColor Yellow
        Write-Host "  Set `$UserPassword in sandbox-config.ps1 or run without -NonInteractive." -ForegroundColor Yellow
        Write-Host ""
        $proceed = Read-Host "  Continue with default password? [y/N]"
        if ($proceed -notmatch '^[Yy]') {
            Write-Host "  Aborted." -ForegroundColor Yellow
            exit 0
        }
    }
}

Install-Sandbox -Config $Config
