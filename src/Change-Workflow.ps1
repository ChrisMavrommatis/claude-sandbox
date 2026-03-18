#Requires -Version 5.1
<#
.SYNOPSIS
    Changes the workflow configuration in claude-sandbox.
.DESCRIPTION
    Use this script to change the workflow configuration in claude-sandbox without needing a full reinstall.
    Copies the selected workflow profile to ~/.bashrc.d/workflow.sh, then tells you to re-source.
    Run from an elevated PowerShell prompt (or normal if WSL doesn't need sudo).
#>


# -- Ensure script is running with Administrator privileges ----------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
    exit 1
}

# -- Ensure required files are present ------------------------------------------------
$RequiredFiles = @(
    "common.ps1",
    "sandbox-config.ps1"
)
foreach ($file in $RequiredFiles) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $file))) {
        Write-Error "Required file '$file' not found in script directory. Please ensure all files are present."
        exit 1
    }
}

# -- Load configuration ---------------------------------------------------------
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\sandbox-config.ps1"

$divider = "-" * 60

## -- Start of script -------------------------------------------------------------------
Write-Host ""
Write-Host $divider -ForegroundColor DarkGray
Write-Host "  Claude Sandbox Change Workflow"       -ForegroundColor White
Write-Host "  Distro : $DistroName"                 -ForegroundColor DarkGray
Write-Host "  User : $Username"                     -ForegroundColor DarkGray   
Write-Host "  Runtime : $ContainerRuntime"          -ForegroundColor DarkGray
Write-Host $divider -ForegroundColor DarkGray
Write-Host ""

## -- Select and apply workflow profile -----------------------------------------------
Write-Step "Select workflow profile..."

### Test for workflow folder 
$WorkflowSourceDir = Join-Path $PSScriptRoot "workflows"
Check-DirectoryExistsOrExit $WorkflowSourceDir

### Get workflow files
$WorkflowFiles = Get-ChildItem -Path $WorkflowSourceDir -Filter "*.sh" -File
if ($WorkflowFiles.Count -eq 0) {
    Write-Error "No workflow files found in '$WorkflowSourceDir'."
    exit 1
}

### List workflow
Write-Info "Found $($WorkflowFiles.Count) workflow(s):"
for ($i = 0; $i -lt $WorkflowFiles.Count; $i++) {
     Write-Host "  [$($i+1)] $($WorkflowFiles[$i].Name)" -ForegroundColor Gray
}
Write-Host ""

### Select workflow
$index = 0
do{
    $raw = Read-Host "Select a workflow (1-$($WorkflowFiles.Count))"
    $valid = [int]::TryParse($raw, [ref]$index) -and $index -ge 1 -and $index -le $WorkflowFiles.Count
    if(-not $valid) {
        Write-Host "Invalid selection. Please enter a number between 1 and $($WorkflowFiles.Count)." -ForegroundColor Red
    }
}
while(-not $valid)


$selectedWorkflow = $WorkflowFiles[$index - 1]
Write-Info "Selected workflow : $($selectedWorkflow.Name)"

### Ensure Projects folder exists in sandbox
Write-Info "Ensuring Projects folder exists in sandbox..."
Execute-InSandbox "mkdir -p /home/$Username/projects" $Username
Execute-InSandbox "mkdir -p /home/$Username/.bashrc.d" $Username
Write-Ok "Projects folder exists in sandbox"

### --- Write selected workflow to ~/.bashrc.d/workflow.sh in the sandbox ------------------------------------------------
Write-Info "Deploying $($selectedWorkflow.Name) profile to sandbox..."

$content = (Get-Content $selectedWorkflow.FullName -Raw -Encoding UTF8) `
    -replace "__PROJECTS_DRVFS__", $ProjectsPath.Replace("\", "\\") `
    -replace "`r`n", "`n"  # Ensure Unix line endings

[System.IO.File]::WriteAllText(
    "\\wsl$\$DistroName\home\$Username\.bashrc.d\workflow.sh",
    $content,
    (New-Object System.Text.UTF8Encoding $false)
)

Write-Ok "Deployed $($selectedWorkflow.Name) profile to sandbox"

