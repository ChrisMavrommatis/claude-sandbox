#Requires -Version 5.1

# Load Private functions first - Public functions may call them
$Private = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $Private) { . $file.FullName }

# Load Public functions
$Public = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $Public) { . $file.FullName }

# Export only Public functions - Private stay internal
Export-ModuleMember -Function $Public.BaseName