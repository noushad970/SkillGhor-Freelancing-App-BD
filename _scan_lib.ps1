$root = 'C:\Users\user\Desktop\SkillGhor-Freelancing-App-BD\lib'

function ByteSeq([int[]]$bytes) {
    return [System.Text.Encoding]::GetEncoding(1252).GetString([byte[]]$bytes)
}

# 1) Mojibake sequences (built byte-exact so PowerShell can't mangle them)
$moj = @(
    (ByteSeq 0xE0,0xA7,0xB3),  # à§³
    (ByteSeq 0xE2,0x80,0xA2),  # â€
    (ByteSeq 0xE2,0x80,0x99),  # â'
    (ByteSeq 0xE2,0x80,0x9C),  # â"
    (ByteSeq 0xE2,0x80,0x9D),  # â"
    (ByteSeq 0xE2,0x80,0x94),  # â”
    (ByteSeq 0xC3,0xA9),        # Ã©
    (ByteSeq 0xC3,0xA0)         # Ã
)

$mojHits = New-Object System.Collections.Generic.List[string]
Get-ChildItem -Path $root -Recurse -File -Include *.dart | ForEach-Object {
    $f = $_.FullName
    $i = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f)) {
        $i++
        foreach ($p in $moj) {
            if ($line.IndexOf($p, [System.StringComparison]::Ordinal) -ge 0) {
                $mojHits.Add(('{0}:{1}: {2}' -f $f, $i, $line))
                break
            }
        }
    }
}
$mojHits | Out-File -FilePath "$env:TEMP\mojibake_hits.txt" -Encoding UTF8

# 2) Unicode escape sequences (ASCII-only)
$uni = @('\u09F3','\u09B9','\u09A4','\u09BE','\u09B8')
$uniHits = New-Object System.Collections.Generic.List[string]
Get-ChildItem -Path $root -Recurse -File -Include *.dart | ForEach-Object {
    $f = $_.FullName
    $i = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f)) {
        $i++
        foreach ($p in $uni) {
            if ($line.IndexOf($p, [System.StringComparison]::Ordinal) -ge 0) {
                $uniHits.Add(('{0}:{1}: {2}' -f $f, $i, $line))
                break
            }
        }
    }
}
$uniHits | Out-File -FilePath "$env:TEMP\unicode_hits.txt" -Encoding UTF8

# 3) Branding strings
$brandHits = New-Object System.Collections.Generic.List[string]
$brandBangla = (ByteSeq 0xE0,0xA6,0xB9,0xE0,0xA6,0xBE,0xE0,0xA6,0xA4,0xE0,0xA6,0xBE,0xE0,0xA6,0xB8) # হাতাস
Get-ChildItem -Path $root -Recurse -File -Include *.dart | ForEach-Object {
    $f = $_.FullName
    $i = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f)) {
        $i++
        if ($line.IndexOf('SkillGhor', [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or $line.IndexOf($brandBangla, [System.StringComparison]::Ordinal) -ge 0) {
            $brandHits.Add(('{0}:{1}: {2}' -f $f, $i, $line))
        }
    }
}
$brandHits | Out-File -FilePath "$env:TEMP\branding_hits.txt" -Encoding UTF8

# 4) Routing cross-reference
$both = New-Object System.Collections.Generic.List[string]
$signin = New-Object System.Collections.Generic.List[string]
$pur = New-Object System.Collections.Generic.List[string]
Get-ChildItem -Path $root -Recurse -File -Include *.dart | ForEach-Object {
    $f = $_.FullName
    $content = [System.IO.File]::ReadAllText($f)
    $hasSignIn = $content.IndexOf('SignInScreen', [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    $hasPUR = $content.IndexOf('pushAndRemoveUntil', [System.StringComparison]::Ordinal) -ge 0
    if ($hasSignIn -and $hasPUR) { $both.Add($f) }
    elseif ($hasSignIn) { $signin.Add($f) }
    elseif ($hasPUR) { $pur.Add($f) }
}
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('BOTH_SignInAndPUR:')
foreach ($x in $both) { [void]$sb.AppendLine($x) }
[void]$sb.AppendLine('---SignIn_only:')
foreach ($x in $signin) { [void]$sb.AppendLine($x) }
[void]$sb.AppendLine('---PUR_only:')
foreach ($x in $pur) { [void]$sb.AppendLine($x) }
$sb.ToString() | Out-File -FilePath "$env:TEMP\routing_refs.txt" -Encoding UTF8

"Mojibake: $($mojHits.Count)  UnicodeEscape: $($uniHits.Count)  Branding: $($brandHits.Count)  Both: $($both.Count)  SignInOnly: $($signin.Count)  PUROnly: $($pur.Count)"
Test-Path 'C:\Users\user\Desktop\SkillGhor-Freelancing-App-BD\lib\screens\home_screen.dart'
