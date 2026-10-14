# 새 티켓 확인. Claude 없이 MCP만 조회해 처음 보는 티켓을 올라온 만큼 알리고, 분석은 실행마다 한 건씩 /cs:run ticket=<ID> 로 맡긴다.
# 사용: powershell -NoProfile -ExecutionPolicy Bypass -File poll.ps1 [-Project 20] [-WorkDir <폴더>]
param([string]$Project = '', [string]$WorkDir = (Get-Location).Path)

# 근무 시간(09:30~18:30)에만 돈다. 그 밖에 올라온 티켓은 다음 근무 시간 첫 조회 때 알린다.
$now = (Get-Date).TimeOfDay
if ($now -lt [TimeSpan]'09:30' -or $now -gt [TimeSpan]'18:30') { exit 0 }

$dir = Join-Path $env:LOCALAPPDATA 'CsCenter'
New-Item -ItemType Directory -Force $dir | Out-Null
$log = Join-Path $dir 'cs-auto.log'
$seenFile = Join-Path $dir 'seen.txt'
$queueFile = Join-Path $dir 'queue.txt'
function Log($m) { Add-Content $log "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" -Encoding UTF8 }

try {
    # ConvertFrom-Json 은 대소문자만 다른 키가 있으면 실패해서 대소문자를 구분하는 파서를 쓴다.
    Add-Type -AssemblyName System.Web.Extensions
    $js = New-Object Web.Script.Serialization.JavaScriptSerializer
    $js.MaxJsonLength = [int]::MaxValue
    # cs-center 연결 설정은 사용자 설정에도, 프로젝트 폴더(.mcp.json)에도 있을 수 있다.
    $cfg = $null
    foreach ($f in @((Join-Path $env:USERPROFILE '.claude.json'), (Join-Path $WorkDir '.mcp.json'))) {
        if (-not (Test-Path $f)) { continue }
        $servers = $js.DeserializeObject((Get-Content $f -Raw -Encoding UTF8))['mcpServers']
        if ($servers -and $servers['cs-center']) { $cfg = $servers['cs-center']; break }
    }
    if (-not $cfg) { Log 'cs-center MCP 연결 설정을 찾지 못했다. Claude에서 cs-center MCP를 먼저 연결하라.'; exit 1 }
    # 웹 안내대로 "Bearer ${CS_CENTER_MCP_TOKEN}" 처럼 환경 변수로 넣은 경우 사용자 환경 변수에서 채운다.
    $auth = [regex]::Replace($cfg['headers']['Authorization'], '\$\{(\w+)\}', {
        param($m) $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value, 'User'); if ($v) { $v } else { [Environment]::GetEnvironmentVariable($m.Groups[1].Value) } })
    $mcp = @{ url = $cfg['url']; headers = @{ Authorization = $auth } }
    $body = '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_my_new_tickets","arguments":{"hours":168,"limit":100}}}'
    $res = Invoke-WebRequest $mcp.url -Method Post -UseBasicParsing -TimeoutSec 30 -Body $body -ContentType 'application/json' `
        -Headers @{ Authorization = $mcp.headers.Authorization; Accept = 'application/json, text/event-stream' }
    # 응답 헤더에 charset이 없어 한글이 깨지므로 바이트를 직접 UTF-8로 읽는다.
    $text = [Text.Encoding]::UTF8.GetString($res.RawContentStream.ToArray())
    $data = ($text -split "`n" | Where-Object { $_ -like 'data: *' } | Select-Object -First 1).Substring(6) | ConvertFrom-Json
    $tickets = ($data.result.content[0].text | ConvertFrom-Json).tickets
} catch {
    Log "조회 실패: $($_.Exception.Message)"
    # 토큰 만료·폐기(401)면 하루 한 번 알리고, 누르면 MCP 연결 관리(재발급)로 간다.
    $expFile = Join-Path $dir 'token-expired.txt'
    if ($_.Exception.Response.StatusCode -eq 401 -and (Get-Content $expFile -ErrorAction SilentlyContinue) -ne (Get-Date -Format 'yyyy-MM-dd')) {
        Set-Content $expFile (Get-Date -Format 'yyyy-MM-dd')
        & (Join-Path $PSScriptRoot 'notify.ps1') 'CS MCP 연결 만료' '눌러서 MCP 연결 관리에서 재발급하세요. 재발급 화면의 설치 한 줄을 실행하면 다시 연결됩니다.' "$($mcp.url -replace '/mcp$', '')/McpSettings"
    }
    exit 1
}

$seen = if (Test-Path $seenFile) { @(Get-Content $seenFile) } else { @() }
# 최근 7일 티켓 중 접수(0)·대기(1)만 본다. 진행·완료된 티켓은 알리지도 분석하지도 않는다. 접수 먼저, 같은 상태는 오래된 순.
$new = @($tickets | Where-Object { "$($_.statusCode)" -in '0', '1' -and "$($_.ticketId)" -notin $seen -and (-not $Project -or "$($_.projectId)" -eq $Project) } | Sort-Object statusCode, ticketId)
$site = $mcp.url -replace '/mcp$', ''

# 새 티켓은 분석 대기열에만 넣는다. 알림은 분석 메모를 등록했을 때만 /cs:run 이 보낸다.
foreach ($t in $new) {
    Add-Content $seenFile $t.ticketId
    Add-Content $queueFile $t.ticketId
    Log "새 티켓 $($t.ticketCode) ($($t.projectName)) $($t.title)"
}

# 분석은 한 번에 한 건만. 실패해도 같은 티켓을 계속 다시 돌지 않도록 대기열에서 먼저 뺀다.
$queue = @(Get-Content $queueFile -ErrorAction SilentlyContinue | Where-Object { $_ })
if (-not $queue) { exit 0 }
# claude: PATH(npm 설치) → 데스크톱 앱 안의 Claude Code(가장 최근 버전). 못 찾으면 대기열을 그대로 두고 끝낸다.
$claude = (Get-Command claude.cmd, claude.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $claude) { $claude = (Get-ChildItem "$env:APPDATA\Claude\claude-code\*\*\claude.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
if (-not $claude) { Log 'claude 실행 파일을 찾지 못해 분석을 건너뛴다.'; exit 1 }
# 백그라운드로만 쓰는 PC도 새 버전을 받도록 분석 전에 하루 한 번 플러그인을 업데이트한다. 실패해도 분석은 그대로 한다.
$updFile = Join-Path $dir 'plugin-updated.txt'
$today = Get-Date -Format 'yyyy-MM-dd'
if ((Get-Content $updFile -ErrorAction SilentlyContinue) -ne $today) {
    & $claude plugin marketplace update emfocus-cs *>> $log
    & $claude plugin update cs@emfocus-cs -s user *>> $log
    Set-Content $updFile $today
    Log '플러그인 업데이트 확인'
}
Set-Content $queueFile @($queue | Select-Object -Skip 1)
$tools = 'mcp__cs-center__get_ticket_maintenance_context mcp__cs-center__get_my_ticket_detail mcp__cs-center__claim_ai_analysis mcp__cs-center__get_ticket_activity mcp__cs-center__get_ticket_attachments mcp__cs-center__download_ticket_attachment mcp__cs-center__add_internal_note mcp__cs-center__change_ticket_status mcp__cs-center__get_my_projects mcp__cs-center__get_project_domain_knowledge Read Grep Glob'
# 무인 실행이라 PowerShell·파일 쓰기는 주지 않는다. 허용: CS 조회·AI 잠금·내부 메모 등록, 소스·캐시 읽기. 알림은 아래에서 이 스크립트가 보낸다.
# 도메인 문서 캐시 폴더와 projects.md 의 작업 소스(읽기용)를 허용 범위에 넣는다. 비교 전용은 넣지 않는다.
$map = Join-Path $env:USERPROFILE '.claude\cs-knowledge\projects.md'
$addDirs = " --add-dir `"$(Split-Path $map)`""
if (Test-Path $map) {
    Get-Content $map -Encoding UTF8 | Where-Object { $_ -match '^\|\s*\d+\s*\|' } | ForEach-Object {
        $src = ($_ -split '\|')[4].Trim()
        if ($src -and (Test-Path $src)) { $addDirs += " --add-dir `"$src`"" }
    }
}
Log "분석 시작 티켓 $($queue[0]) (남은 대기 $($queue.Count - 1)건)"
# claude 출력은 UTF-8이라 받기 전에 맞춘다(안 하면 로그·알림 한글이 깨짐).
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# 작업 폴더를 사용자 폴더가 아닌 cs-knowledge 로 둔다. 사용자 폴더로 두면 ~/.claude.json(토큰)·.ssh 까지 읽기 범위에 들어간다.
$aiDir = Split-Path $map
New-Item -ItemType Directory -Force $aiDir | Out-Null
$out = cmd.exe /c "cd /d `"$aiDir`" && `"$claude`" -p `"/cs:run ticket=$($queue[0]) url=$site/Tickets/$($queue[0])`" --allowedTools $tools$addDirs 2>&1"
$out | ForEach-Object { Add-Content $log $_ -Encoding UTF8 }
# 메모를 등록했을 때만 알린다(/cs:run 이 마지막에 MEMO_OK|번호|제목 을 출력).
$ok = $out | Where-Object { $_ -like 'MEMO_OK|*' } | Select-Object -Last 1
if ($ok) {
    $p = $ok -split '\|', 3
    & (Join-Path $PSScriptRoot 'notify.ps1') "티켓 $($p[1]) 분석 메모 등록 - 확인 필요" $p[2] "$site/Tickets/$($queue[0])"
}
