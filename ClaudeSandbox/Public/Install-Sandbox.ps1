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

    # -- Step 2: Create WSL distro --------------------------------------------------------
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

    Write-Info "Importing '$DistroImage' as WSL distro '$DistroName'..."
    Initialize-Directory $InstallDir
    wsl --import $DistroName $InstallDir $TarPath --version 2 | Out-Null
    Assert-ExitCode "Failed to import distro '$DistroName'. Check that the distro doesn't already exist (wsl --list)."
    Write-Ok "Distro imported to $InstallDir"

    Write-Ok "Step 2 Complete: WSL distro '$DistroName' created from '$DistroImage'"

    # -- Step 3: Configure the sandbox ----------------------------------------------------
    Write-Step "Step 3: Configuring the sandbox environment..."

    Write-Info "Installing packages..."
    Invoke-InSandbox $DistroName "apt-get update && apt-get upgrade -y && apt-get install -y $($Packages -join ' ')"
    Write-Ok "Packages installed"

    Write-Info "Creating user '$Username'..."
    $escapedPassword = $UserPassword -replace "'", "'\'''" -replace '\$', '\$' -replace '`', '\`' -replace '"', '\"'
    Invoke-InSandbox $DistroName "useradd -m -s /bin/bash $Username && printf '%s:%s\n' '$Username' '$escapedPassword' | chpasswd && usermod -aG sudo $Username"
    Write-Ok "User '$Username' created and added to sudo group"

    Write-Info "Writing wsl.conf..."
    $wslConfPath = Get-AssetPath "wsl.conf"
    $wslConfContent = (Get-Content $wslConfPath -Raw) `
        -replace "__DistroName__", $DistroName `
        -replace "__Username__",   $Username
    Write-FileToDistro $DistroName "/etc/wsl.conf" $wslConfContent
    Write-Ok "wsl.conf written"

    Write-Info "Restarting distro to apply wsl.conf..."
    Restart-Sandbox $DistroName
    Write-Ok "Distro restarted"

    Write-Info "Creating .claude persistence directory..."
    Invoke-InSandbox $DistroName "mkdir -p ~/.claude" $Username
    Write-Ok ".claude directory created"

    Write-Info "Configuring persistence directory mount in fstab..."
    $userUid = (wsl -d $DistroName --user $Username -- id -u).Trim()
    $userGid = (wsl -d $DistroName --user $Username -- id -g).Trim()
    $fstabLine = "$ClaudePersistenceDir /home/$Username/.claude drvfs uid=$userUid,gid=$userGid,umask=022,metadata 0 0"
    Write-FileToDistro $DistroName "/tmp/claude-fstab.tmp" $fstabLine
    Invoke-InSandbox $DistroName "cat /tmp/claude-fstab.tmp >> /etc/fstab && rm /tmp/claude-fstab.tmp"
    Write-Ok "Persistence directory mount configured"

    Write-Info "Creating symlink for ~/.claude.json persistence file..."
    Invoke-InSandbox $DistroName "ln -sf /home/$Username/.claude/.claude.json /home/$Username/.claude.json" $Username
    Write-Ok "Symlink for ~/.claude.json created"

    Write-Info "Restarting distro to apply fstab changes..."
    Restart-Sandbox $DistroName
    Write-Ok "Distro restarted"

    Write-Info "Configuring sudo password feedback..."
    Invoke-InSandbox $DistroName "echo 'Defaults pwfeedback' >> /etc/sudoers.d/pwfeedback" "root"
    Write-Ok "sudo password feedback enabled"

    ### Install Claude Code
    # Write-Info "Installing Claude Code..."
    # Invoke-InSandbox $DistroName "curl -fsSL https://claude.ai/install.sh | bash" $Username
    # Write-Ok "Claude Code installed"

    Write-Info "Creating projects and .bashrc.d directories..."
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/projects" $Username
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/.bashrc.d" $Username
    Write-Ok "Directories created"

    Write-Ok "Step 3 Complete: Sandbox environment configured"

    # -- Step 4: Default profile and workflow ---------------------------------------------
    Write-Step "Step 4: Adding default bashrc profile and workflow..."

    Write-Info "Deploying default bashrc profile..."
    $profilePath = Get-AssetPath "profiles\default.sh"
    $profileContent = Get-Content $profilePath -Raw -Encoding UTF8
    Write-FileToDistro $DistroName "/home/$Username/.bashrc" $profileContent
    Write-Ok "Default bashrc profile deployed"

    Write-Info "Deploying default workflow..."
    $workflowPath = Get-AssetPath "workflows\default.sh"
    $workflowContent = (Get-Content $workflowPath -Raw -Encoding UTF8) `
        -replace "__PROJECTS_DRVFS__", $ProjectsPath.Replace("\", "\\")
    Write-FileToDistro $DistroName "/home/$Username/.bashrc.d/workflow.sh" $workflowContent
    Write-Ok "Default workflow deployed"

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

    # -- Done -----------------------------------------------------------------------------
    Write-Banner "Installation Complete" @{
        Launch    = "wsl -d $DistroName"
        Run       = "claude"
        Uninstall = "./Uninstall-ClaudeSandbox.ps1"
    }
}
