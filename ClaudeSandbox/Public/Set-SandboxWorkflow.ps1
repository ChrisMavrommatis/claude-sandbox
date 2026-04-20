function Set-SandboxWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$WorkflowName
    )

    $DistroName   = $Config.DistroName
    $Username     = $Config.Username
    $ProjectsPath = $Config.ProjectsPath

    $workflowsDir = Get-AssetPath "workflows"
    $workflowPath = Join-Path $workflowsDir $WorkflowName
    if (-not (Test-Path "$workflowPath")) {
        Write-Error "Workflow '$WorkflowName' not found in '$workflowsDir'."
        exit 1
    }

    # Ensure directories exist [I-011]
    Write-Info "Ensuring directories exist in sandbox..."
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/projects" $Username
    Invoke-InSandbox $DistroName "mkdir -p /home/$Username/.bashrc.d" $Username

    # Deploy workflow with token replacement [I-007]
    Write-Info "Deploying $WorkflowName to sandbox..."
    $content = (Get-Content $workflowPath -Raw -Encoding UTF8) `
        -replace "__PROJECTS_DRVFS__", $ProjectsPath.Replace("\", "\\")
    Write-FileToDistro $DistroName "/home/$Username/.bashrc.d/workflow.sh" $content
    Write-Ok "Deployed '$WorkflowName' to sandbox"
}
