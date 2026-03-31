@{
    ModuleVersion     = '1.0.0'
    GUID              = "CFFAEE3F-BD22-4CE6-9CF6-161ACC0E4D3E"
    Author            = 'Chris Mavrommatis'
    CompanyName       = 'Atcom S.A.'
    PowerShellVersion = '5.1'
    RootModule        = 'ClaudeSandbox.psm1'
    FunctionsToExport = @(
        'Install-Sandbox',
        'Uninstall-Sandbox',
        'Set-SandboxProfile',
        'Set-SandboxWorkflow',
        'Add-TerminalProfile',
        'Remove-TerminalProfile',
        'Invoke-InSandbox',
        'Restart-Sandbox',
        'Test-Sandbox',
        'Set-SandboxPolicy'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}