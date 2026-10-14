# 공개 저장소 마켓플레이스는 기본으로 자동 업데이트가 꺼져 있어서, 사용자 설정의 emfocus-cs 항목에 autoUpdate 를 켠다.
# 사용자가 이미 autoUpdate 를 적어 뒀으면(꺼 둔 경우 포함) 건드리지 않는다.
$f = Join-Path $env:USERPROFILE '.claude\settings.json'
if (-not (Test-Path $f)) { exit 0 }
$s = [IO.File]::ReadAllText($f)
$m = [regex]::Match($s, '"emfocus-cs"\s*:\s*\{')
if (-not $m.Success) { exit 0 }
# 항목 끝(짝 맞는 닫는 괄호)까지 잘라 autoUpdate 가 있는지 본다.
$depth = 0; $end = $m.Index + $m.Length - 1
for ($i = $end; $i -lt $s.Length; $i++) {
    if ($s[$i] -eq '{') { $depth++ } elseif ($s[$i] -eq '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
}
if ($s.Substring($m.Index, $end - $m.Index) -match '"autoUpdate"') { exit 0 }
$s = $s.Insert($m.Index + $m.Length, ' "autoUpdate": true,')
# 원래 파일에 BOM이 있었으면 그대로 둔다(사내 규칙 UTF-8 BOM과 맞추기).
$bom = [IO.File]::ReadAllBytes($f)[0..2] -join ',' -eq '239,187,191'
[IO.File]::WriteAllText($f, $s, (New-Object Text.UTF8Encoding($bom)))
