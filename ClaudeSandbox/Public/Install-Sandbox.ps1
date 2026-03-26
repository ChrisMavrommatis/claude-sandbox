function Install-Sandbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Assert-Administrator

    $DistroName           = $Config.DistroName
    $DistroImage          = $Config.DistroImage
    $Username             = $Config.Username
    $UserPassword         = $Config.UserPassword
    $ProjectsPath         = $Config.ProjectsPath
    $ClaudePersistenceDir = $Config.ClaudePersistenceDir
    $ContainerRuntime     = $Config.ContainerRuntime
    $Packages             = $Config.Packages
    $InstallDir           = $Config.InstallDir

    # Warn if password is still the default [S-013]
    if ($UserPassword -eq "changeme") {
        Write-Host ""
        Write-Host "  WARNING: Password is still set to 'changeme' in sandbox-config.ps1" -ForegroundColor Yellow
        Write-Host "  Change it before using the sandbox in any shared environment." -ForegroundColor Yellow
        Write-Host ""
        $proceed = Read-Host "  Continue with default password? [y/N]"
        if ($proceed -notmatch '^[Yy]') {
            Write-Host "  Aborted. Edit sandbox-config.ps1 and re-run." -ForegroundColor Yellow
            exit 0
        }
    }

    # -- Preparation ----------------------------------------------------------------------
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "claude-sandbox-install"
    Initialize-Directory $tempDir
    $TarPath = Join-Path $tempDir "claude-sandbox.tar"

    Write-Banner "Claude Sandbox Installer" @{
        Distro  = $DistroName
        User    = $Username
        Runtime = $ContainerRuntime
    }

    # -- Step 1: WSL ----------------------------------------------------------------------
    Write-Step "Step 1: WSL2 setup"

    Write-Info "Installing WSL2 (if not already installed)..."
    wsl --install --no-distribution 2>$null | Out-Null
    Assert-ExitCode "Failed to install WSL2. Ensure WSL is enabled and try again."
    wsl --set-default-version 2 | Out-Null
    Assert-ExitCode "Failed to set WSL default version to 2."

    Write-Ok "Step 1 Complete: WSL2 ready"

    # -- Step 2: Create WSL distro [I-001] ------------------------------------------------
    Write-Step "Step 2: Creating container image from $DistroImage..."

    Write-Info "Creating container from '$DistroImage'..."
    $ContainerId = & $ContainerRuntime create $DistroImage
    if (-not $ContainerId) {
        Write-Host "  ERROR: Failed to create container. Check your container runtime." -ForegroundColor Red
        exit 1
    }
    Write-Ok "Container created with ID $ContainerId"

    Write-Info "Exporting to tarball..."
    & $ContainerRuntime export $ContainerId --output=$TarPath
    if (-not (Test-Path $TarPath)) {
        Write-Host "  ERROR: Failed to export container to tarball." -ForegroundColor Red
        exit 1
    }
    Write-Ok "Container exported to $TarPath"

    Write-Info "Cleaning up container..."
    & $ContainerRuntime rm $ContainerId | Out-Null
    $imageId = & $ContainerRuntime images -q $DistroImage
    if ($imageId) {
        Write-Info "Removing container image..."
        & $ContainerRuntime rmi $imageId | Out-Null
    }
    Write-Ok "Container removed"

    # Imports distro into WSL [I-001]
    Write-Info "Importing '$DistroImage' as WSL distro '$DistroName'..."
    Initialize-Directory $InstallDir
    wsl --import $DistroName $InstallDir $TarPath --version 2 | Out-Null
    Assert-ExitCode "Failed to import distro '$DistroName'. Check that the distro doesn't already exist (wsl --list)."
    Write-Ok "Distro imported to $InstallDir"

    Write-Ok "Step 2 Complete: WSL distro '$DistroName' created from '$DistroImage'"

    # -- Step 3: Configure the sandbox ----------------------------------------------------
    Write-Step "Step 3: Configuring the sandbox environment..."

    # Install required packages [I-004.1 through I-004.N]
    Write-Info "Installing packages..."
    Invoke-InSandbox $DistroName "apt-get update && apt-get upgrade -y && apt-get install -y $($Packages -join ' ')"
    Write-Ok "Packages installed"

    # Create user and add to sudo group [I-002, I-003, S-007]
    Write-Info "Creating user '$Username'..."
    $escapedPassword = $UserPassword -replace "'", "'\'''" -replace '\$', '\$' -replace '`', '\`' -replace '"', '\"'
    Invoke-InSandbox $DistroName "useradd -m -s /bin/bash $Username && printf '%s:%s\n' '$Username' '$escapedPassword' | chpasswd && usermod -aG sudo $Username"
    Write-Ok "User '$Username' created and added to sudo group"

    # Deploy wsl.conf [I-005, S-001, S-002, S-003, S-004, S-005, S-006]
    Write-Info "Writing wsl.conf..."
    $wslConfPath = Get-AssetPath "wsl.conf"
    $gpuValue = if ($Config.GpuEnabled) { "true" } else { "false" }
    $wslConfContent = (Get-Content $wslConfPath -Raw) `
        -replace "__DistroName__",  $DistroName `
        -replace "__Username__",    $Username `
        -replace "__GpuEnabled__",  $gpuValue
    Write-FileToDistro $DistroName "/etc/wsl.conf" $wslConfContent
    Write-Ok "wsl.conf written"

    Write-Info "Restarting distro to apply wsl.conf..."
    Restart-Sandbox $DistroName
    Write-Ok "Distro restarted"

    # Create .claude persistence directory [I-008]
    Write-Info "Creating .claude persistence directory..."
    Invoke-InSandbox $DistroName "mkdir -p ~/.claude" $Username
    Write-Ok ".claude directory created"

    # Configure persistence mount in fstab [I-009, S-010, S-011]
    Write-Info "Configuring persistence directory mount in fstab..."
    $userUid = (wsl -d $DistroName --user $Username -- id -u).Trim()
    $userGid = (wsl -d $DistroName --user $Username -- id -g).Trim()
    $fstabLine = "$ClaudePersistenceDir /home/$Username/.claude drvfs uid=$userUid,gid=$userGid,umask=022,metadata 0 0"
    Write-FileToDistro $DistroName "/tmp/claude-fstab.tmp" $fstabLine
    Invoke-InSandbox $DistroName "cat /tmp/claude-fstab.tmp >> /etc/fstab && rm /tmp/claude-fstab.tmp"
    Write-Ok "Persistence directory mount configured"

    # Create .claude.json symlink [I-010]
    Write-Info "Creating symlink for ~/.claude.json persistence file..."
    Invoke-InSandbox $DistroName "ln -sf /home/$Username/.claude/.claude.json /home/$Username/.claude.json" $Username
    Write-Ok "Symlink for ~/.claude.json created"

    Write-Info "Restarting distro to apply fstab changes..."
    Restart-Sandbox $DistroName
    Write-Ok "Distro restarted"

    # Configure sudo password feedback [S-008]
    Write-Info "Configuring sudo password feedback..."
    Invoke-InSandbox $DistroName "echo 'Defaults pwfeedback' >> /etc/sudoers.d/pwfeedback" "root"
    Write-Ok "sudo password feedback enabled"

    # Install Claude Code [I-012]
    Write-Info "Installing Claude Code..."
    Invoke-InSandbox $DistroName "curl -fsSL https://claude.ai/install.sh | bash" $Username
    Write-Ok "Claude Code installed"

    # Create projects and .bashrc.d directories [I-011]
    Write-Info "Creating projects and .bashrc.d directories..."
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/projects" $Username
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/.bashrc.d" $Username
    Write-Ok "Directories created"

    Write-Ok "Step 3 Complete: Sandbox environment configured"

    # -- Step 4: Default profile and workflow [I-006, I-007] --------------------------------
    Write-Step "Step 4: Adding default bashrc profile and workflow..."

    Set-SandboxProfile -Config $Config -ProfileName "default.sh"
    Set-SandboxWorkflow -Config $Config -WorkflowName "default.sh"

    Write-Ok "Step 4 Complete: Default profile and workflow added"

    # -- Step 5: Windows Terminal profile -------------------------------------------------
    Write-Step "Step 5: Adding Windows Terminal profile..."
    Add-TerminalProfile -Config $Config
    Write-Ok "Step 5 Complete: Windows Terminal profile added"

    # -- Step 6: Cleanup ------------------------------------------------------------------
    Write-Step "Step 6: Cleaning up temporary files..."
    Remove-Item $tempDir -Recurse -ErrorAction SilentlyContinue
    Invoke-InSandbox $DistroName "rm -f /tmp/claude-fstab.tmp"
    Write-Ok "Step 6 Complete: Temporary files cleaned up"

    # -- Step 7: Verify installation -----------------------------------------------------
    Write-Step "Step 7: Verifying installation..."
    Test-Sandbox -Config $Config

    # -- Done -----------------------------------------------------------------------------
    Write-Banner "Installation Complete" @{
        Launch    = "wsl -d $DistroName"
        Run       = "claude"
        Uninstall = "./Uninstall-ClaudeSandbox.ps1"
    }
}
