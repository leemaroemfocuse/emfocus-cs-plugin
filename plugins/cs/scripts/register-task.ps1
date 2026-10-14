# CS 자동 유지보수를 Windows 작업 스케줄러에 등록한다. Claude 창을 열지 않아도 로그온 상태면 주기적으로 실행된다.
# 주기마다 poll.ps1 이 새 티켓만 조회하고(Claude 미사용), 새 티켓이 있을 때만 알림 + /cs:run 분석·메모를 돌린다.
# 사용: powershell -ExecutionPolicy Bypass -File register-task.ps1 [-Minutes 5] [-Project 20] [-WorkDir <소스 폴더>]
# 해제: /cs:stop (꺼 둔 표시 stopped.txt 를 남겨 세션 시작 때 다시 등록되지 않게 한다). 이 스크립트를 실행하면(/cs:start·설치) 표시를 지우고 다시 켠다.
param([int]$Minutes = 5, [string]$Project = '', [string]$WorkDir = $env:USERPROFILE)
# 출력(한글·경로)을 UTF-8로 내보낸다. Claude가 이 출력을 UTF-8로 읽기 때문에 시스템 코드 페이지로 쓰면 깨진다.
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)

$pollArgs = "-WorkDir '$WorkDir'" + $(if ($Project) { " -Project $Project" } else { '' })
# 업데이트로 플러그인 폴더가 바뀌어도 다시 등록할 필요 없게, 실행할 때마다 지금 설치된 버전(installed_plugins.json 의 installPath)의 poll.ps1 을 쓴다.
# 폴더 수정 시각으로 고르면 같은 시각에 받은 예전 폴더를 고를 수 있어서 쓰지 않는다.
$latest = "(Get-Content `$env:USERPROFILE\.claude\plugins\installed_plugins.json -Raw | ConvertFrom-Json).plugins.'cs@emfocus-cs'[0].installPath + '\scripts\poll.ps1'"
# conhost --headless: 콘솔 창을 띄우지 않는다.
$action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"& ($latest) $pollArgs`""
# 근무 시간(09:30~18:30)에만 조회한다. 매일 09:30에 시작해 9시간 동안 반복한다.
# 09:30 이후에 PC를 켜면 로그온 때 한 번 바로 확인한다(근무 시간 밖이면 poll.ps1 이 바로 끝낸다).
$daily = New-ScheduledTaskTrigger -Daily -At '09:30'
$daily.Repetition = (New-ScheduledTaskTrigger -Once -At '09:30' -RepetitionInterval (New-TimeSpan -Minutes $Minutes) -RepetitionDuration (New-TimeSpan -Hours 9)).Repetition
$triggers = @($daily, (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME))
# 이전 실행이 안 끝났으면 새로 시작하지 않는다(겹침 방지).
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
# Description 은 세션 시작 훅이 예약 방식이 바뀌었는지 판단하는 표시다. 방식을 바꾸면 값도 올린다.
Remove-Item (Join-Path $env:LOCALAPPDATA 'CsCenter\stopped.txt') -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName 'CS 자동 유지보수' -Description 'cs-poll v4' -Action $action -Trigger $triggers -Settings $settings -Force | Out-Null
"등록 완료: 09:30~18:30 ${Minutes}분 간격 새 티켓 확인$(if ($Project) { ", 프로젝트 $Project" }), 작업 폴더 $WorkDir, 로그 $(Join-Path $env:LOCALAPPDATA 'CsCenter\cs-auto.log')"
