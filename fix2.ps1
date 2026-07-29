$root = 'C:\Users\user\Desktop\SkillGhor-Freelancing-App-BD\lib'

$badArrow = [string][char]0xE2 + [char]0x2020 + [char]0x2019
$goodArrow = [string][char]0x2192

Write-Output ('Bad arrow UTF-8 bytes: ' + ([System.Text.Encoding]::UTF8.GetBytes($badArrow) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
Write-Output ('Good arrow UTF-8 bytes: ' + ([System.Text.Encoding]::UTF8.GetBytes($goodArrow) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')

# 1) Fix freelancer_home arrow
$file1 = Join-Path $root 'screens\freelancer_home_screen.dart'
$b1 = [System.IO.File]::ReadAllBytes($file1)
$t1 = [System.Text.Encoding]::UTF8.GetString($b1)
$old1 = 'View All Jobs ' + $badArrow
$new1 = 'View All Jobs ' + $goodArrow
if ($t1.Contains($old1)) {
    $t1b = $t1.Replace($old1, $new1)
    [System.IO.File]::WriteAllBytes($file1, [System.Text.Encoding]::UTF8.GetBytes($t1b))
    Write-Output 'FIXED: freelancer_home_screen.dart arrow'
} else {
    Write-Output 'SKIP: freelancer_home_screen.dart arrow (pattern not found)'
}

# 2) Fix notification_service broken template
$file2 = Join-Path $root 'services\notification_service.dart'
$b2 = [System.IO.File]::ReadAllBytes($file2)
$t2 = [System.Text.Encoding]::UTF8.GetString($b2)
$taka = [string][char]0x09F3
$old2 = 'You received ' + $taka + '$amount for'
$new2 = 'You received ' + $taka + '${amount.toStringAsFixed(0)} for'
if ($t2.Contains($old2)) {
    $t2b = $t2.Replace($old2, $new2)
    [System.IO.File]::WriteAllBytes($file2, [System.Text.Encoding]::UTF8.GetBytes($t2b))
    Write-Output 'FIXED: notification_service.dart taka interpolation'
} else {
    Write-Output 'SKIP: notification_service.dart taka (pattern not found)'
}

# VERIFY
Write-Output ''
Write-Output '--- VERIFY ---'
$all = Get-ChildItem -Path $root -Recurse -Filter '*.dart'
$remaining = 0
foreach ($f in $all) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $t = [System.Text.Encoding]::UTF8.GetString($b)
    if ($t.Contains($badArrow)) {
        Write-Output ('REMAIN: ' + $f.FullName)
        $remaining++
    }
}
Write-Output ('Total remaining corruptions: ' + $remaining)

$content = Get-Content (Join-Path $root 'screens\freelancer_home_screen.dart') -Encoding UTF8
Write-Output ('Line 946: ' + $content[945])
$content2 = Get-Content (Join-Path $root 'services\notification_service.dart') -Encoding UTF8
Write-Output ('Line 356: ' + $content2[355])