#!/bin/sh
# 세션 시작 시 CS 자동 유지보수 안내를 컨텍스트로 넣는다. 프로젝트 소스 위치를 아직 정리하지 않았으면 그것부터 하게 한다.
map="$HOME/.claude/cs-knowledge/projects.md"

# 플러그인 자동 업데이트를 켜 두고, 새 티켓 알림 예약 작업이 없거나, 예전 방식이거나, 업데이트로 플러그인 폴더가 바뀌었으면 다시 등록한다(09:30~18:30, 5분 간격).
if [ "$OS" = "Windows_NT" ]; then
  reg=$(cygpath -w "${CLAUDE_PLUGIN_ROOT}/scripts/register-task.ps1" 2>/dev/null || echo "${CLAUDE_PLUGIN_ROOT}/scripts/register-task.ps1")
  root=$(cygpath -w "${CLAUDE_PLUGIN_ROOT}" 2>/dev/null || echo "${CLAUDE_PLUGIN_ROOT}")
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    \$t = Get-ScheduledTask -TaskName 'CS 자동 유지보수' -ErrorAction SilentlyContinue
    if (-not \$t -or \$t.Description -ne 'cs-poll v2' -or \$t.Actions[0].Arguments -notlike '*$root*') {
      & '$reg' -Minutes 5 -WorkDir '$(pwd -W 2>/dev/null || pwd)' | Out-Null
    }
    & '$root/scripts/auto-update.ps1'" >/dev/null 2>&1 &
fi
if [ -f "$map" ]; then
  setup=""
else
  setup="이 PC에는 아직 CS 프로젝트별 소스 위치(~/.claude/cs-knowledge/projects.md)가 없다. 첫 응답에서 사용자의 요청을 처리한 뒤, 사용자에게 알리고 /cs:setup 절차로 프로젝트별 로컬 소스 위치를 찾아 저장한다. "
fi
cat <<JSON
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${setup}cs 플러그인 자동 업데이트 켜짐. CS 자동 유지보수(cs 플러그인)가 설치돼 있다. 이 세션의 첫 응답 끝에 다음 한 줄을 반드시 덧붙여 사용자에게 알린다(사용자가 먼저 묻지 않아도 알린다): \"CS 티켓 자동 처리: /cs:run 1 (여러 건은 /cs:run 3, 전체는 /cs:run all, 사용법은 /cs:help)\". 단, 사용자가 시키지 않는 한 /cs:run 을 자동으로 실행하지는 않는다. 두 번째 응답부터는 다시 알리지 않는다. 사용자가 자동 처리(백그라운드·예약 실행)를 끄라고 하면 묻지 말고 /cs:stop 절차대로 바로 끄고, 켜라고 하면 /cs:start, 도는지 물으면 /cs:status 절차를 따른다."}}
JSON
