# ═══════════════════════════════════════════════════════════════════════════════
# Claude Sandbox Workflow — Default
# This is the default workflow profile.
# It is selected by default during installation, and can be re-applied at any
# time using Change-Workflow.ps1
#
# ═══════════════════════════════════════════════════════════════════════════════

Write-Step "Workflow: Default ---------------------------------"

$tempDir = Join-Path $PSScriptRoot "../../temp"

### Ensure Projects folder exists in sandbox
Write-Info "Ensuring Projects folder exists in sandbox..."
Execute-InSandbox "mkdir -p /home/$Username/projects" $Username
Execute-InSandbox "mkdir -p /home/$Username/.bashrc.d" $Username
Write-Ok "Projects folder exists in sandbox"

### Take Contents of /workflows/default.sh and write to ~/.bashrc.d/workflow.sh in the sandbox
Write-Info "Deploying workflow profile to sandbox..."
$WorkflowSourcePath = Join-Path $PSScriptRoot "default.sh"
$WorkflowContent = (Get-Content $WorkflowSourcePath -Raw) `
    -replace "__PROJECTS_DRVFS__", $ProjectsPath.Replace("\", "\\") `
    -replace "`r`n", "`n"  # Ensure Unix line endings
$WorkflowTempPath = Join-Path $tempDir "workflow.sh"

Ensure-DirectoryExists $tempDir
[System.IO.File]::WriteAllText($WorkflowTempPath, $WorkflowContent, (New-Object System.Text.UTF8Encoding $false))

$WorkflowDestPath = "\\wsl$\$DistroName\home\$Username\.bashrc.d\workflow.sh"
try {
    Copy-Item $WorkflowTempPath $WorkflowDestPath -ErrorAction Stop
} catch {
    Write-Host "  ERROR: Failed to deploy workflow profile: $_" -ForegroundColor Red
    exit 1
}
Write-Ok "Workflow profile deployed to sandbox"