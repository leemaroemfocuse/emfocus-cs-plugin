# 세션 시작: 업데이트 방식에 맞춰 자동 업데이트를 켜거나 끄고, 새 버전이 있으면 바뀐 내용을 모아 알리고, 알림 예약이 없거나 예전 방식이면 다시 등록한 뒤, 사용 안내를 컨텍스트로 넣는다. sh 없는 PC에서도 돈다.
& (Join-Path $PSScriptRoot '..\scripts\auto-update.ps1')
$t = Get-ScheduledTask -TaskName 'CS 자동 유지보수' -ErrorAction SilentlyContinue
# 사용자가 /cs:stop 으로 꺼 뒀으면(stopped.txt) 다시 등록하지 않는다.
$stopped = Test-Path (Join-Path $env:LOCALAPPDATA 'CsCenter\stopped.txt')
if (-not $stopped -and (-not $t -or $t.Description -ne 'cs-poll v3')) { & (Join-Path $PSScriptRoot '..\scripts\register-task.ps1') | Out-Null }

$setup = ''
if (-not (Test-Path (Join-Path $env:USERPROFILE '.claude\cs-knowledge\projects.md'))) {
    $setup = '이 PC에는 아직 CS 프로젝트별 소스 위치(~/.claude/cs-knowledge/projects.md)가 없다. 첫 응답에서 사용자의 요청을 처리한 뒤, 사용자에게 알리고 /cs:setup 절차로 프로젝트별 로컬 소스 위치를 찾아 저장한다. '
}
# 업데이트 안내. 방식(update-mode.txt): auto 자동 / 그 외 물어봄. 바뀐 내용은 설치된 버전 이후 커밋 제목을 한 번에 모아 보여 준다.
$cs = Join-Path $env:LOCALAPPDATA 'CsCenter'
$mp = Join-Path $env:USERPROFILE '.claude\plugins\marketplaces\emfocus-cs'
$update = ''
try {
    $mode = Get-Content (Join-Path $cs 'update-mode.txt') -ErrorAction SilentlyContinue | Select-Object -First 1
    $installed = [regex]::Match((Get-Content (Join-Path $env:USERPROFILE '.claude\plugins\installed_plugins.json') -Raw), '"cs@emfocus-cs"[\s\S]*?"gitCommitSha"\s*:\s*"(\w+)"').Groups[1].Value
    git -C $mp fetch -q origin 2>$null
    $latest = git -C $mp rev-parse origin/main 2>$null
    if ($mode -eq 'auto') {
        # 자동: 업데이트는 Claude가 알아서 받는다. 지난번 알린 뒤로 설치된 변경을 한 번에 모아 알린다.
        $seenFile = Join-Path $cs 'announced-sha.txt'
        $seen = Get-Content $seenFile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($seen -and $installed -and $seen -ne $installed) {
            $log = @(git -C $mp log --format='- %s' "$seen..$installed" -- plugins install.ps1 2>$null)
            if ($log) { $update = "CS 플러그인이 자동 업데이트되었다. 첫 응답 끝에 '이번에 업데이트된 내용' 제목으로 다음 목록을 빠짐없이 그대로 보여 준다:`n$($log -join "`n")`n" }
        }
        if ($installed) { Set-Content $seenFile $installed }
    } elseif ($installed -and $latest -and $installed -ne $latest -and (Get-Content (Join-Path $cs 'skipped-sha.txt') -ErrorAction SilentlyContinue) -ne $latest) {
        $log = @(git -C $mp log --format='- %s' "$installed..$latest" -- plugins install.ps1 2>$null)
        if ($log) {
            $update = "CS 플러그인 새 버전이 있다. 첫 응답 끝에 '업데이트할 내용' 제목으로 다음 목록을 빠짐없이 그대로 보여 주고(여러 번 쌓였으면 전부), 이어서 '1. 업데이트(이번 버전 받기) 2. 업데이트 안 함(이번 버전 건너뜀, 더 새 버전이 나오면 다시 물어봄) 3. 자동 업데이트(앞으로 묻지 않고 받음)' 중 고르게 한다. 고르면 각각 /cs:update once, /cs:update skip, /cs:update auto 절차를 따른다. 이 세션에서 한 번만 묻는다:`n$($log -join "`n")`n"
        }
    }
} catch { }

# 'cs 플러그인 자동 업데이트 켜짐' 은 MCP 서버가 예전 버전 사용자를 가려내는 표시다. 지우지 않는다.
$context = $update + $setup + 'cs 플러그인 자동 업데이트 켜짐. CS 자동 유지보수(cs 플러그인)가 설치돼 있다. 이 세션의 첫 응답 끝에 다음 한 줄을 반드시 덧붙여 사용자에게 알린다(사용자가 먼저 묻지 않아도 알린다): "CS 티켓 자동 처리: /cs:run 1 (여러 건은 /cs:run 3, 전체는 /cs:run all, 사용법은 /cs:help)". 단, 사용자가 시키지 않는 한 /cs:run 을 자동으로 실행하지는 않는다. 두 번째 응답부터는 다시 알리지 않는다. 사용자가 자동 처리(백그라운드·예약 실행)를 끄라고 하면 묻지 말고 /cs:stop 절차대로 바로 끄고, 켜라고 하면 /cs:start, 도는지 물으면 /cs:status 절차를 따른다.'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } } | ConvertTo-Json -Compress
