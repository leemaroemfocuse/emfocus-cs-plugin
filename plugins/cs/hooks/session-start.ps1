# 세션 시작: 자동 업데이트를 켜 두고, 알림 예약이 없거나 예전 방식이면 다시 등록한 뒤, 사용 안내를 컨텍스트로 넣는다. sh 없는 PC에서도 돈다.
& (Join-Path $PSScriptRoot '..\scripts\auto-update.ps1')
$t = Get-ScheduledTask -TaskName 'CS 자동 유지보수' -ErrorAction SilentlyContinue
# 사용자가 /cs:stop 으로 꺼 뒀으면(stopped.txt) 다시 등록하지 않는다.
$stopped = Test-Path (Join-Path $env:LOCALAPPDATA 'CsCenter\stopped.txt')
if (-not $stopped -and (-not $t -or $t.Description -ne 'cs-poll v3')) { & (Join-Path $PSScriptRoot '..\scripts\register-task.ps1') | Out-Null }

$setup = ''
if (-not (Test-Path (Join-Path $env:USERPROFILE '.claude\cs-knowledge\projects.md'))) {
    $setup = '이 PC에는 아직 CS 프로젝트별 소스 위치(~/.claude/cs-knowledge/projects.md)가 없다. 첫 응답에서 사용자의 요청을 처리한 뒤, 사용자에게 알리고 /cs:setup 절차로 프로젝트별 로컬 소스 위치를 찾아 저장한다. '
}
# 'cs 플러그인 자동 업데이트 켜짐' 은 MCP 서버가 예전 버전 사용자를 가려내는 표시다. 지우지 않는다.
$context = $setup + 'cs 플러그인 자동 업데이트 켜짐. CS 자동 유지보수(cs 플러그인)가 설치돼 있다. 이 세션의 첫 응답 끝에 다음 한 줄을 반드시 덧붙여 사용자에게 알린다(사용자가 먼저 묻지 않아도 알린다): "CS 티켓 자동 처리: /cs:run 1 (여러 건은 /cs:run 3, 전체는 /cs:run all, 사용법은 /cs:help)". 단, 사용자가 시키지 않는 한 /cs:run 을 자동으로 실행하지는 않는다. 두 번째 응답부터는 다시 알리지 않는다. 사용자가 자동 처리(백그라운드·예약 실행)를 끄라고 하면 묻지 말고 /cs:stop 절차대로 바로 끄고, 켜라고 하면 /cs:start, 도는지 물으면 /cs:status 절차를 따른다.'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } } | ConvertTo-Json -Compress
