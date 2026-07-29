$paths = @(
    "$env:TEMP\mojibake_hits.txt",
    "$env:TEMP\unicode_hits.txt",
    "$env:TEMP\branding_hits.txt",
    "$env:TEMP\routing_refs.txt"
)
foreach ($p in $paths) {
    Write-Host "=====FILE:$p====="
    if (Test-Path $p) {
        $bytes = [System.IO.File]::ReadAllBytes($p)
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        Write-Host $text
    } else {
        Write-Host "(missing)"
    }
}