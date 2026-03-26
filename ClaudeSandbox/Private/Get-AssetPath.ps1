function Get-AssetPath([string]$RelativePath) {
    $path = Join-Path "$PSScriptRoot\..\Assets" $RelativePath
    if (-not (Test-Path $path)) {
        Write-Error "Module asset not found: $RelativePath"
        exit 1
    }
    return $path
}
