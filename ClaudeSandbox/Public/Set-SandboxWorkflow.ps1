function Set-SandboxWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Assert-Administrator

    $DistroName   = $Config.DistroName
    $Username     = $Config.Username
    $ProjectsPath = $Config.ProjectsPath

    Write-Banner "Claude Sandbox - Change Workflow" @{
        Distro = $DistroName
        User   = $Username
    }

    # -- Select workflow ------------------------------------------------------------------
    Write-Step "Select workflow profile..."

    $workflowsDir = Get-AssetPath "workflows"
    $workflowFiles = Get-ChildItem -Path $workflowsDir -Filter "*.sh" -File
    if ($workflowFiles.Count -eq 0) {
        Write-Error "No workflow files found in '$workflowsDir'."
        exit 1
    }

    Write-Info "Found $($workflowFiles.Count) workflow(s):"
    for ($i = 0; $i -lt $workflowFiles.Count; $i++) {
        Write-Host "  [$($i+1)] $($workflowFiles[$i].Name)" -ForegroundColor Gray
    }
    Write-Host ""

    $index = 0
    do {
        $raw = Read-Host "Select a workflow (1-$($workflowFiles.Count))"
        $valid = [int]::TryParse($raw.Trim(), [ref]$index) -and $index -ge 1 -and $index -le $workflowFiles.Count
        if (-not $valid) {
            Write-Host "  Invalid selection. Enter a number between 1 and $($workflowFiles.Count)." -ForegroundColor Red
        }
    } while (-not $valid)

    $selectedWorkflow = $workflowFiles[$index - 1]
    Write-Ok "Selected workflow: $($selectedWorkflow.Name)"

    # -- Ensure directories exist ---------------------------------------------------------
    Write-Info "Ensuring directories exist in sandbox..."
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/projects" $Username
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/.bashrc.d" $Username
    Write-Ok "Directories ready"

    # -- Deploy workflow with token replacement -------------------------------------------
    $name = $selectedWorkflow.Name
    Write-Info "Deploying $name to sandbox..."
    $content = (Get-Content $selectedWorkflow.FullName -Raw -Encoding UTF8) `
        -replace "__PROJECTS_DRVFS__", $ProjectsPath.Replace("\", "\\")
    Write-FileToDistro $DistroName "/home/$Username/.bashrc.d/workflow.sh" $content
    Write-Ok "Deployed $name to sandbox"
}
