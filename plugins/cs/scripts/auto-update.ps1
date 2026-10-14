# 사용자 설정(~/.claude/settings.json)의 emfocus-cs 마켓플레이스 autoUpdate 를 업데이트 방식에 맞춘다.
# 자동 업데이트는 쓰지 않는다(보안 검토: 검토 없는 코드가 바로 실행되지 않게). 업데이트는 세션 시작 때 바뀐 내용을 보여 주고 사용자가 고른다.
$want = 'false'
$f = Join-Path $env:USERPROFILE '.claude\settings.json'
if (-not (Test-Path $f)) { exit 0 }
$s = [IO.File]::ReadAllText($f)
$m = [regex]::Match($s, '"emfocus-cs"\s*:\s*\{')
if (-not $m.Success) { exit 0 }
# 항목 끝(짝 맞는 닫는 괄호)까지 잘라 autoUpdate 를 바꾸거나 넣는다.
$depth = 0; $end = $m.Index + $m.Length - 1
for ($i = $end; $i -lt $s.Length; $i++) {
    if ($s[$i] -eq '{') { $depth++ } elseif ($s[$i] -eq '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
}
$entry = $s.Substring($m.Index, $end - $m.Index)
$new = if ($entry -match '"autoUpdate"\s*:\s*(true|false)') { $entry -replace '"autoUpdate"\s*:\s*(true|false)', "`"autoUpdate`": $want" }
       else { $entry.Insert($m.Length, " `"autoUpdate`": $want,") }
if ($new -eq $entry) { exit 0 }
$s = $s.Substring(0, $m.Index) + $new + $s.Substring($end)
# 원래 파일에 BOM이 있었으면 그대로 둔다(사내 규칙 UTF-8 BOM과 맞추기).
$bom = [IO.File]::ReadAllBytes($f)[0..2] -join ',' -eq '239,187,191'
[IO.File]::WriteAllText($f, $s, (New-Object Text.UTF8Encoding($bom)))
