# Skill Ghor UTF-8 corruption cleanup script
$root = 'C:\Users\user\Desktop\SkillGhor-Freelancing-App-BD\lib'

# Corrupt byte sequences (Latin-1 bytes re-encoded as UTF-8)
$badEmDash  = [char]0xC3 + [char]0xA2 + [char]0xE2 + [char]0x82 + [char]0xAC  # â€"
$goodEmDash = [char]0xE2 + [char]0x80 + [char]0x94                           # —

$badArr  = [char]0xC3 + [char]0xA2 + [char]0xE2 + [char]0x82 + [char]0xAC + [char]0xE2 + [char]0x82 + [char]0xAC  # â€"
$goodArr = [char]0xE2 + [char]0x80 + [char]0x94                             # —

$badArrow  = 'â†' + [char]0xCB + [char]0x99 # â†'
$goodArrow = [char]0xE2 + [char]0x86 + [char]0x92 # →

$badTaka  = [char]0xC3 + [char]0xA0 + [char]0xC2 + [char]0xA7 + [char]0xC2 + [char]0xB3 # à§³
$goodTaka = [char]0xE0 + [char]0xA7 + [char]0xB3                                      # ৳

$fixes = @(
    @{
        Path = 'screens\active_contracts_screen.dart'
        Sub  = @(
            @{ P = 'Completion requested ' + $badEmDash + ' waiting for client finalization'; R = 'Completion requested — waiting for client finalization' }
        )
    },
    @{
        Path = 'services\notification_service.dart'
        Sub  = @(
            @{ P = 'You received ' + $badTaka + '$amount'; R = 'You received ৳${amount.toStringAsFixed(0)}' }
        )
    },
    @{
        Path = 'screens\hired_freelancers_screen.dart'
        Sub  = @(
            @{ P = 'Marked as completed ' + $badEmDash + ' awaiting freelancer review'; R = 'Marked as completed — awaiting freelancer review' }
        )
    },
    @{
        Path = 'screens\freelancer_home_screen.dart'
        Sub  = @(
            @{ P = 'View All Jobs ' + $badArrow; R = 'View All Jobs →' }
        )
    }
)

foreach ($fix in $fixes) {
    $full = Join-Path $root $fix.Path
    $bytes = [System.IO.File]::ReadAllBytes($full)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $changed = $false
    foreach ($s in $fix.Sub) {
        if ($text.Contains($s.P)) {
            $text = $text.Replace($s.P, $s.R)
            $changed = $true
            Write-Output ('  - replaced in ' + $fix.Path)
        }
    }
    if ($changed) {
        [System.IO.File]::WriteAllText($full, $text, [System.Text.Encoding]::UTF8)
        Write-Output ('FIXED: ' + $fix.Path)
    } else {
        Write-Output ('SKIP: ' + $fix.Path)
    }
}

# client_home_screen.dart - all 5 corruption sites are `à§³` → ৳
$client = Join-Path $root 'screens\client_home_screen.dart'
$cb = [System.IO.File]::ReadAllBytes($client)
$ct = [System.Text.Encoding]::UTF8.GetString($cb)
$cnt = ([regex]::Matches($ct, [regex]::Escape($badTaka))).Count
if ($cnt -gt 0) {
    $ct2 = $ct.Replace($badTaka, $goodTaka)
    [System.IO.File]::WriteAllText($client, $ct2, [System.Text.Encoding]::UTF8)
    Write-Output ('FIXED: client_home_screen.dart - ' + $cnt + ' taka sites')
} else {
    Write-Output 'SKIP: client_home_screen.dart (no taka corruption)'
}

Write-Output ''
Write-Output '--- VERIFY ---'
$allFiles = Get-ChildItem -Path $root -Recurse -Filter '*.dart'
$remaining = 0
foreach ($f in $allFiles) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $t = [System.Text.Encoding]::UTF8.GetString($b)
    foreach ($pat in @($badEmDash, $badArr, $badArrow, $badTaka)) {
        if ($t.Contains($pat)) {
            Write-Output ('REMAIN: ' + $f.FullName + ' -> ' + $pat)
            $remaining++
        }
    }
}
Write-Output ('Total remaining corruptions: ' + $remaining)
