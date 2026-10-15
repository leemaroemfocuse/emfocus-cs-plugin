---
description: CS 자동 유지보수 사용 방식 바꾸기. 인자 - 1(자동 분석) | 2(알림만) | 3(MCP만)
argument-hint: "1|2|3"
---

인자: `$ARGUMENTS`. 인자가 없으면 지금 방식(`%LOCALAPPDATA%\CsCenter\mode.txt`, 없으면 자동 분석)을 알려 주고 다음 중 고르게 한다.

1. 자동 분석: 새 티켓을 AI가 분석해 내부 메모로 남기고, 메모가 등록되면 알림
2. 알림만: 새 티켓이 올라오면 알림만, AI 분석은 실행하지 않음
3. MCP만: 알림·자동 분석 없이 연결만, 물어볼 때만 티켓 조회(이 플러그인과 예약 작업을 지움)

고르면 PowerShell로 실행하고 결과를 한 줄로 알린다. 아래 `claude`가 PATH에 없으면 `%APPDATA%\Claude\claude-code\*\*\claude.exe` 중 가장 최근 것을 쓴다.

- 1 또는 2: `Set-Content "$env:LOCALAPPDATA\CsCenter\mode.txt" auto`(2면 `notify`) 후 `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/register-task.ps1"`로 예약 작업을 켠다. 바로 적용된다.
- 3: `Set-Content "$env:LOCALAPPDATA\CsCenter\mode.txt" mcp; Unregister-ScheduledTask -TaskName "CS 자동 유지보수" -Confirm:$false -ErrorAction SilentlyContinue; claude plugin uninstall cs@emfocus-cs -s user`. "Claude를 다시 열면 적용됩니다. 다시 쓰려면 CS Center > MCP 연결 관리의 설치 문장을 실행하세요"라고 알린다.

방식은 업데이트해도 바뀌지 않는다.
