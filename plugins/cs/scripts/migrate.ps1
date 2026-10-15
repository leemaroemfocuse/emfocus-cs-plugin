# 플러그인 출처를 옛 공개 저장소에서 회사 CS 저장소(cs-mcp 폴더)로 옮긴다. 세션 시작 훅이 뒤에서 한 번 실행한다.
# 플러그인 이름(cs@emfocus-cs)이 같아서 사용 방식·예약 작업·꺼 둔 상태는 그대로다. 실패하면 옛 저장소로 되돌린다.
# 사용: powershell -NoProfile -ExecutionPolicy Bypass -File migrate.ps1 [-Target EmfocusCorp/proj-emfocus-cs | <로컬 폴더>]
param([string]$Target = $(if ($env:CS_MIGRATE_TARGET) { $env:CS_MIGRATE_TARGET } else { 'EmfocusCorp/proj-emfocus-cs' }))
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$dir = Join-Path $env:LOCALAPPDATA 'CsCenter'
New-Item -ItemType Directory -Force $dir | Out-Null
$log = Join-Path $dir 'migrate.log'
$lock = Join-Path $dir 'migrate.lock'
$needLogin = Join-Path $dir 'migrate-needs-login.txt'
function Log($m) { Add-Content $log "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" -Encoding UTF8 }

# 한 번에 하나만. 30분 넘은 잠금은 끊긴 실행으로 보고 무시한다.
if ((Test-Path $lock) -and ((Get-Item $lock).LastWriteTime -gt (Get-Date).AddMinutes(-30))) { exit 0 }
Set-Content $lock (Get-Date -Format s)
try {
    $claude = (Get-Command claude.cmd, claude.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $claude) { $claude = (Get-ChildItem "$env:APPDATA\Claude\claude-code\*\*\claude.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
    if (-not $claude) { Log 'claude 실행 파일을 찾지 못해 옮기지 않음'; exit 1 }
    function Run { Add-Content $log "> claude $($args -join ' ')" -Encoding UTF8; & $claude @args 2>&1 | ForEach-Object { Add-Content $log "  $_" -Encoding UTF8 } }

    $isPath = Test-Path $Target
    # 회사 저장소는 비공개다. 이 PC의 GitHub 로그인으로 접근되는지 먼저 본다(로그인 창은 띄우지 않음).
    if (-not $isPath) {
        $env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'
        git ls-remote "https://github.com/$Target.git" HEAD 2>&1 | Out-Null
        # git 에 저장된 로그인이 없고 GitHub CLI(gh)에 로그인돼 있으면 그 로그인을 git 에 연결하고 다시 본다.
        if ($LASTEXITCODE -ne 0 -and (Get-Command gh -ErrorAction SilentlyContinue)) {
            gh auth status 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { gh auth setup-git --hostname github.com 2>&1 | Out-Null; Log 'gh 로그인을 git 에 연결함'; git ls-remote "https://github.com/$Target.git" HEAD 2>&1 | Out-Null }
        }
        if ($LASTEXITCODE -ne 0) { Set-Content $needLogin $Target; Log "회사 저장소 접근 안 됨($Target). GitHub 로그인 필요"; exit 1 }
    }
    Remove-Item $needLogin -ErrorAction SilentlyContinue

    # 되돌릴 곳: 지금 등록된 마켓플레이스 출처(GitHub 저장소 또는 폴더).
    $km = Get-Content (Join-Path $env:USERPROFILE '.claude\plugins\known_marketplaces.json') -Raw -Encoding UTF8
    $m = [regex]::Match($km, '"emfocus-cs"\s*:\s*\{\s*"source"\s*:\s*\{[^}]*?"(?:repo|path)"\s*:\s*"([^"]+)"')
    $old = $m.Groups[1].Value -replace '\\\\', '\'
    if (-not $old) { Log '지금 마켓플레이스 출처를 찾지 못해 옮기지 않음'; exit 1 }
    Log "옮기기 시작: $old -> $Target"

    Run plugin marketplace remove emfocus-cs
    if ($isPath) { Run plugin marketplace add $Target } else { Run plugin marketplace add $Target --sparse .claude-plugin cs-mcp }
    Run plugin install cs@emfocus-cs -s user

    # 새 출처에서 정식판(cs, cs-mcp 폴더)이 설치됐는지 확인한다.
    $ip = [regex]::Match((Get-Content (Join-Path $env:USERPROFILE '.claude\plugins\installed_plugins.json') -Raw), '"cs@emfocus-cs"[\s\S]*?"installPath"\s*:\s*"([^"]+)"').Groups[1].Value -replace '\\\\', '\'
    $ok = $ip -and (Test-Path (Join-Path $ip 'scripts\poll.ps1')) -and (Test-Path (Join-Path $ip 'hooks\session-start.ps1'))
    $km2 = Get-Content (Join-Path $env:USERPROFILE '.claude\plugins\known_marketplaces.json') -Raw -Encoding UTF8
    $ok = $ok -and ($km2 -match [regex]::Escape(($Target -replace '\\', '\\')))
    if ($ok) { Log "옮기기 완료: $ip"; exit 0 }

    # 실패: 옛 출처로 되돌린다. 플러그인이 없는 채로 두지 않는다.
    Log '옮기기 실패. 옛 저장소로 되돌림'
    Run plugin marketplace remove emfocus-cs
    Run plugin marketplace add $old
    Run plugin install cs@emfocus-cs -s user
    exit 1
} finally {
    Remove-Item $lock -ErrorAction SilentlyContinue
}
