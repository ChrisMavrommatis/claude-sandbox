@{
    ModuleVersion     = '1.0.0'
    GUID              = "CFFAEE3F-BD22-4CE6-9CF6-161ACC0E4D3E"
    Author            = 'Chris Mavrommatis'
    CompanyName       = 'Atcom S.A.'
    PowerShellVersion = '5.1'
    RootModule        = 'ClaudeSandbox.psm1'
    FunctionsToExport = @(
        'Invoke-InSandbox',
        'Restart-Sandbox'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}