# 로컬 드라이브에서 소스 저장소 루트(.git/.svn)를 찾아 "경로<TAB>종류<TAB>최근커밋" 으로 출력한다.
# 출력(한글·경로)을 UTF-8로 내보낸다. Claude가 이 출력을 UTF-8로 읽기 때문에 시스템 코드 페이지로 쓰면 깨진다.
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$skip = 'Windows|Program Files|ProgramData|\$Recycle|AppData|node_modules'
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
    Get-ChildItem $_.Root -Directory -Hidden -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in '.git', '.svn' -and $_.FullName -notmatch $skip }
} | ForEach-Object {
    $root = $_.Parent.FullName
    $last = if ($_.Name -eq '.git') { (git -C $root log -1 --format='%ci %s' 2>$null) } else { '' }
    "$root`t$($_.Name.TrimStart('.'))`t$last"
}
