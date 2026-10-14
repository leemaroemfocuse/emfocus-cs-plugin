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

# MCP 도구 하나를 Claude 없이 직접 호출해 결과 JSON을 돌려준다.
function McpCall($name, $argsJson) {
    $body = '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"' + $name + '","arguments":' + $argsJson + '}}'
    $res = Invoke-WebRequest $mcp.url -Method Post -UseBasicParsing -TimeoutSec 30 -Body $body -ContentType 'application/json' `
        -Headers @{ Authorization = $mcp.headers.Authorization; Accept = 'application/json, text/event-stream' }
    # 응답 헤더에 charset이 없어 한글이 깨지므로 바이트를 직접 UTF-8로 읽는다.
    $text = [Text.Encoding]::UTF8.GetString($res.RawContentStream.ToArray())
    $data = ($text -split "`n" | Where-Object { $_ -like 'data: *' } | Select-Object -First 1).Substring(6) | ConvertFrom-Json
    $data.result.content[0].text | ConvertFrom-Json
}

try {
    # ConvertFrom-Json 은 대소문자만 다른 키가 있으면 실패해서 대소문자를 구분하는 파서를 쓴다.
    Add-Type -AssemblyName System.Web.Extensions
    $js = New-Object Web.Script.Serialization.JavaScriptSerializer
    $js.MaxJsonLength = [int]::MaxValue
    # cs-center 연결은 설치 때 등록한 사용자 설정(~/.claude.json)에서만 읽는다. 폴더의 .mcp.json 은 보지 않는다(토큰이 다른 서버로 가지 않게).
    $servers = $js.DeserializeObject((Get-Content (Join-Path $env:USERPROFILE '.claude.json') -Raw -Encoding UTF8))['mcpServers']
    $cfg = if ($servers) { $servers['cs-center'] }
    if (-not $cfg) { Log 'cs-center MCP 연결 설정을 찾지 못했다. CS Center > MCP 연결 관리의 설치 문장으로 먼저 연결하라.'; exit 1 }
    if ("$($cfg['url'])" -notlike 'https://*') { Log "cs-center MCP 주소가 https 가 아니라 중단한다: $($cfg['url'])"; exit 1 }
    # 웹 안내대로 "Bearer ${CS_CENTER_MCP_TOKEN}" 처럼 환경 변수로 넣은 경우 사용자 환경 변수에서 채운다.
    $auth = [regex]::Replace($cfg['headers']['Authorization'], '\$\{(\w+)\}', {
        param($m) $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value, 'User'); if ($v) { $v } else { [Environment]::GetEnvironmentVariable($m.Groups[1].Value) } })
    $mcp = @{ url = $cfg['url']; headers = @{ Authorization = $auth } }
    $tickets = (McpCall 'get_my_new_tickets' '{"hours":168,"limit":100}').tickets
} catch {
    Log "조회 실패: $($_.Exception.Message)"
    # 토큰 만료·폐기(401)면 하루 한 번 알리고, 누르면 MCP 연결 관리(재발급)로 간다.
    $expFile = Join-Path $dir 'token-expired.txt'
    if ($_.Exception.Response.StatusCode -eq 401 -and (Get-Content $expFile -ErrorAction SilentlyContinue) -ne (Get-Date -Format 'yyyy-MM-dd')) {
        Set-Content $expFile (Get-Date -Format 'yyyy-MM-dd')
        & (Join-Path $PSScriptRoot 'notify.ps1') 'CS MCP 연결 만료' '눌러서 MCP 연결 관리에서 [재발급]을 누르고, 화면의 토큰 교체 문장을 Claude에 붙여 넣으세요.' "$($mcp.url -replace '/mcp$', '')/McpSettings"
    }
    exit 1
}

$seen = if (Test-Path $seenFile) { @(Get-Content $seenFile) } else { @() }
# 최근 7일 티켓 중 접수(0)만 본다(고객 대기·진행·완료는 알리지도 분석하지도 않는다). 진행·완료된 티켓은 알리지도 분석하지도 않는다. 접수 먼저, 같은 상태는 오래된 순.
$new = @($tickets | Where-Object { "$($_.statusCode)" -eq '0' -and "$($_.ticketId)" -notin $seen -and (-not $Project -or "$($_.projectId)" -eq $Project) } | Sort-Object statusCode, ticketId)
$site = $mcp.url -replace '/mcp$', ''

# 알림만(mode.txt=notify)이면 새 티켓을 바로 알리고 AI는 돌리지 않는다.
# 자동 분석이면 대기열에만 넣고, 알림은 분석 메모를 등록했을 때만 보낸다.
$mode = (Get-Content (Join-Path $dir 'mode.txt') -ErrorAction SilentlyContinue | Select-Object -First 1)
foreach ($t in $new) {
    Add-Content $seenFile $t.ticketId
    if ($mode -eq 'notify') { & (Join-Path $PSScriptRoot 'notify.ps1') "새 티켓 $($t.ticketCode) · $($t.companyName)" $t.title "$site/Tickets/$($t.ticketId)" }
    else { Add-Content $queueFile $t.ticketId }
    Log "새 티켓 $($t.ticketCode) ($($t.projectName)) $($t.title)"
}

# 분석은 한 번에 한 건만. 실패해도 같은 티켓을 계속 다시 돌지 않도록 대기열에서 먼저 뺀다.
# claude: PATH(npm 설치) → 데스크톱 앱 안의 Claude Code(가장 최근 버전). 못 찾으면 대기열을 그대로 두고 끝낸다.
$claude = (Get-Command claude.cmd, claude.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $claude) { $claude = (Get-ChildItem "$env:APPDATA\Claude\claude-code\*\*\claude.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
if (-not $claude) { Log 'claude 실행 파일을 찾지 못해 업데이트·분석을 건너뛴다.'; exit 1 }
# 업데이트는 하지 않는다. 사람이 Claude를 열 때 바뀐 내용을 보고 고른다.
# 분석 전에 Claude 없이 잠금부터 건다. 다른 사람의 AI가 먼저 잡았거나 이미 분석된 티켓은 토큰을 쓰지 않고 건너뛰고,
# 같은 실행에서 바로 다음 대기 티켓을 시도한다(5분을 기다리지 않음).
$queue = @(Get-Content $queueFile -ErrorAction SilentlyContinue | Where-Object { $_ })
while ($queue) {
    $id = $queue[0] -as [long]; $queue = @($queue | Select-Object -Skip 1)
    if (-not $id) { continue }
    Set-Content $queueFile $queue
    try { $lock = McpCall 'claim_ai_analysis' "{`"ticketId`":$id}" } catch { Log "잠금 실패 티켓 ${id}: $($_.Exception.Message)"; continue }
    if ($lock.success) { $queue = @($id) + $queue; break }
    Log "건너뜀 티켓 ${id}: $($lock.message)"
}
if (-not $queue) { exit 0 }
# 무인 실행 권한(2026-10-14 실제 시험으로 확인한 내용 반영).
# - 사용자 설정의 기본 권한 방식(auto 등)에 따라 --allowedTools 만으로는 막히지 않는다(Bash·바깥 파일 읽기가 실행됨).
#   그래서 기본 도구는 --tools 로 Read·Grep·Glob 만 남기고, 민감한 경로 읽기는 --disallowedTools 로 막는다(거부 규칙은 항상 적용).
# - MCP는 --strict-mcp-config 로 cs-center 하나만 붙인다(이 PC의 다른 DB용 MCP는 쓰지 못함).
#   cs-center 쓰기 도구는 AI 잠금·내부 메모 등록만 남기고 나머지는 거부한다.
$allow = 'mcp__cs-center__get_ticket_maintenance_context mcp__cs-center__get_my_ticket_detail mcp__cs-center__claim_ai_analysis mcp__cs-center__get_ticket_activity mcp__cs-center__get_ticket_attachments mcp__cs-center__download_ticket_attachment mcp__cs-center__add_internal_note mcp__cs-center__get_my_projects mcp__cs-center__get_project_domain_knowledge Read Grep Glob'
$deny = @('mcp__cs-center__delete_ticket', 'mcp__cs-center__change_ticket_status', 'mcp__cs-center__assign_ticket', 'mcp__cs-center__assign_ticket_to_me',
    'mcp__cs-center__add_ticket_comment', 'mcp__cs-center__reply_to_ticket_comment', 'mcp__cs-center__upload_ticket_attachment', 'mcp__cs-center__update_ticket_fields',
    'mcp__cs-center__set_ticket_schedule', 'mcp__cs-center__record_project_change_history', 'mcp__cs-center__claim_tickets')
foreach ($t in 'Read', 'Grep', 'Glob') {
    foreach ($p in '~/.claude.json', '~/.claude.json.backup', '~/.claude/.credentials.json', '~/.claude/projects/**', '~/.claude/settings*.json', '~/.ssh/**', '~/.aws/**', '~/.git-credentials', '~/.config/**', '~/AppData/**', '~/Desktop/**', '~/Documents/**', '~/Downloads/**') { $deny += "$t($p)" }
}
# 도메인 문서 캐시 폴더(작업 폴더)와 projects.md 의 작업 소스(읽기용). 비교 전용은 넣지 않는다.
$map = Join-Path $env:USERPROFILE '.claude\cs-knowledge\projects.md'
$aiDir = Split-Path $map
New-Item -ItemType Directory -Force $aiDir | Out-Null
$dirs = @()
if (Test-Path $map) {
    Get-Content $map -Encoding UTF8 | Where-Object { $_ -match '^\|\s*\d+\s*\|' } | ForEach-Object {
        $src = ($_ -split '\|')[4].Trim()
        if ($src -and (Test-Path $src)) { $dirs += '--add-dir', $src }
    }
}
# cs-center 연결만 담은 MCP 설정. 실행이 끝나면 지운다.
$mcpFile = Join-Path $dir 'mcp-run.json'
@{ mcpServers = @{ 'cs-center' = @{ type = 'http'; url = $mcp.url; headers = @{ Authorization = $mcp.headers.Authorization } } } } | ConvertTo-Json -Depth 5 | Set-Content $mcpFile -Encoding UTF8
$ticketId = [long]$queue[0]
Log "분석 시작 티켓 $ticketId (남은 대기 $($queue.Count - 1)건)"
# claude 출력은 UTF-8이라 받기 전에 맞춘다(안 하면 로그·알림 한글이 깨짐).
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Push-Location $aiDir
try {
    $raw = & $claude -p "/cs:run ticket=$ticketId url=$site/Tickets/$ticketId" --tools 'Read,Grep,Glob' --strict-mcp-config --mcp-config $mcpFile `
        --allowedTools $allow --disallowedTools ($deny -join ' ') @dirs --output-format stream-json --verbose 2>&1
} finally { Pop-Location; Remove-Item $mcpFile -ErrorAction SilentlyContinue }
# 무엇을 했는지 남긴다: 부른 도구와 읽은 파일 경로(내용은 남기지 않음), 그리고 최종 답변.
$out = @()
foreach ($line in $raw) {
    try { $e = "$line" | ConvertFrom-Json } catch { if ("$line" -notlike 'Warning: no stdin*') { Log "출력: $line" }; continue }
    if ($e.type -eq 'assistant') {
        foreach ($c in @($e.message.content | Where-Object { $_.type -eq 'tool_use' })) {
            $what = @($c.input.file_path, $c.input.path, $c.input.pattern, $c.input.ticketId) | Where-Object { $_ } | Select-Object -First 2
            Log "티켓 $ticketId 도구: $($c.name) $($what -join ' ')"
        }
    } elseif ($e.type -eq 'result') {
        $out = @("$($e.result)" -split "`r?`n")
        Log "티켓 $ticketId 결과($($e.subtype)):"
        $out | ForEach-Object { Add-Content $log $_ -Encoding UTF8 }
    }
}
# 메모를 등록했을 때만 알린다(/cs:run 이 마지막 줄에 MEMO_OK|번호|제목 을 출력).
# 알림 문구는 AI 출력이 아니라 서버 목록의 티켓 번호·제목으로 만든다(티켓 내용으로 알림 문구를 꾸미지 못하게).
if (@($out | ForEach-Object { "$_" } | Where-Object { $_ -like "MEMO_OK|*" })) {
    $t = $tickets | Where-Object { "$($_.ticketId)" -eq "$ticketId" } | Select-Object -First 1
    $code = if ($t) { $t.ticketCode } else { "#$ticketId" }
    & (Join-Path $PSScriptRoot 'notify.ps1') "티켓 $code 분석 메모 등록 - 확인 필요" "$($t.title)" "$site/Tickets/$ticketId"
} elseif (-not @($out | ForEach-Object { "$_" } | Where-Object { $_ -like "*분석 대상 아님*" })) {
    # 잠금까지 걸었는데 메모를 못 남겼으면(오류·중단·권한 문제) 실패도 알린다. 누르면 티켓을 열어 직접 확인한다. 원인은 cs-auto.log.
    $t = $tickets | Where-Object { "$($_.ticketId)" -eq "$ticketId" } | Select-Object -First 1
    $code = if ($t) { $t.ticketCode } else { "#$ticketId" }
    Log "분석 실패 티켓 $ticketId (메모 등록 안 됨)"
    & (Join-Path $PSScriptRoot 'notify.ps1') "티켓 $code AI 분석 실패 - 직접 확인" "$($t.title)" "$site/Tickets/$ticketId"
}
