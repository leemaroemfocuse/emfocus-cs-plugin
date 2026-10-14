# CS 자동 유지보수 한 번에 설치·업데이트. 처음 설치든 예전 설치를 최신으로 올리든 이것 하나로 끝난다.
# 사용(PowerShell 한 줄, 토큰은 새로 연결할 때만):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/leemaroemfocuse/emfocus-cs-plugin/main/install.ps1))) [-Endpoint <MCP 주소> -Token <토큰>]
# 순서: claude 찾기 → MCP 연결 → 플러그인 설치·업데이트 → 자동 업데이트 켜기 → 알림 예약 등록 → 연결 확인 → 테스트 알림
param([string]$Endpoint = '', [string]$Token = '', [string]$WorkDir = $env:USERPROFILE)
$ok = @(); $warn = @()
# 다른 PC에서 실패했을 때 원인을 볼 수 있게 각 명령 출력을 남긴다.
$logDir = Join-Path $env:LOCALAPPDATA 'CsCenter'; New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir 'install.log'
Set-Content $log "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] 설치 시작 $env:COMPUTERNAME" -Encoding UTF8
function Run { Add-Content $log "> claude $($args -join ' ' -replace 'Bearer \S+', 'Bearer ***')" -Encoding UTF8; & $claude @args 2>&1 | ForEach-Object { Add-Content $log "$_" -Encoding UTF8 } }

# 1. claude 실행 파일: PATH(npm 설치) → 데스크톱 앱 안의 Claude Code(가장 최근 버전)
$claude = (Get-Command claude.cmd, claude.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $claude) { $claude = (Get-ChildItem "$env:APPDATA\Claude\claude-code\*\*\claude.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
if (-not $claude) { Write-Output '실패: claude 실행 파일을 찾지 못했습니다. Claude 데스크톱 앱이나 Claude Code를 먼저 설치하세요.'; return }
$ok += "claude: $claude"
# 플러그인은 GitHub에서 git 으로 받는다.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Output '실패: Git이 없습니다. https://git-scm.com/download/win 에서 Git for Windows를 설치한 뒤 다시 실행하세요.'; return }

# 2. MCP 연결. 토큰을 받았을 때만 새로 연결하고, 없으면 기존 연결을 그대로 쓴다.
if ($Endpoint -and $Token) {
    Run mcp remove cs-center -s user
    Run mcp add --transport http cs-center $Endpoint --header "Authorization: Bearer $Token" -s user
    $ok += 'MCP 연결 등록'
}

# 3. 플러그인. 이미 있으면 add/install 은 그냥 넘어가고 update 가 최신으로 올린다.
Run plugin marketplace add leemaroemfocuse/emfocus-cs-plugin
Run plugin marketplace update emfocus-cs
Run plugin install cs@emfocus-cs -s user
Run plugin update cs@emfocus-cs -s user
$root = Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache\emfocus-cs\cs" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $root) { Write-Output "실패: 플러그인 설치에 실패했습니다. 기록: $log"; Get-Content $log -Tail 15; return }
$ok += "플러그인 설치·업데이트 ($($root.Name))"

# 4~5. 자동 업데이트 켜기, 알림 예약 등록(실행할 때마다 최신 설치 버전을 찾으므로 업데이트 후 다시 등록할 필요 없음)
& "$($root.FullName)\scripts\auto-update.ps1"
$ok += '자동 업데이트 켜짐'
& "$($root.FullName)\scripts\register-task.ps1" -WorkDir $WorkDir | Out-Null
if (Get-ScheduledTask -TaskName 'CS 자동 유지보수' -ErrorAction SilentlyContinue) { $ok += '새 티켓 알림 예약 (매일 09:30~18:30, 5분 간격)' } else { $warn += '알림 예약 등록 실패' }

# 6. 연결 확인
$mcp = (& $claude mcp list 2>$null) | Select-String '^cs-center:'
if ("$mcp" -match 'Connected') { $ok += 'MCP 연결 확인' }
elseif ($mcp) { $warn += "MCP 연결 안 됨: $mcp (토큰이 만료됐으면 CS Center에서 다시 발급)" }
else { $warn += 'MCP 연결 없음: CS Center > MCP 연결 관리에서 토큰을 발급하고 그 화면의 설치 문장으로 다시 실행' }

# 7. 테스트 알림
& "$($root.FullName)\scripts\notify.ps1" 'CS 자동 유지보수 설치 완료' '새 티켓이 올라오면 이렇게 알려 드립니다.'

Write-Output '== CS 자동 유지보수 설치 결과'
$ok | ForEach-Object { "완료: $_" }
$warn | ForEach-Object { "확인 필요: $_" }
Write-Output '백그라운드 AI 권한: CS 티켓 조회, 분석 잠금, 내부 메모 등록(고객에게 안 보임), 등록한 소스 폴더 읽기만 허용(상태·담당자 변경, 고객 댓글, PowerShell 실행, 파일 쓰기 없음). 실행 기록은 %LOCALAPPDATA%\CsCenter\cs-auto.log'
Write-Output "설치 기록: $log"
Write-Output '마지막으로 Claude를 닫았다가 다시 여세요.'
