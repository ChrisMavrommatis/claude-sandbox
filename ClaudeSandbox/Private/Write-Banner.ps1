function Write-Banner([string]$title, [hashtable]$fields) {
    $divider = "-" * 60
    Write-Host ""
    Write-Host $divider -ForegroundColor DarkGray
    Write-Host "  $title" -ForegroundColor White
    foreach ($key in $fields.Keys) {
        Write-Host "  $key : $($fields[$key])" -ForegroundColor DarkGray
    }
    Write-Host $divider -ForegroundColor DarkGray
    Write-Host ""
}
