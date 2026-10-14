# EMFOCUS CS Center 자동 유지보수 플러그인

CS Center 새 티켓을 근무 시간(매일 09:30~18:30)에 5분 간격으로 확인합니다. Windows 작업 스케줄러가 실행하므로 Claude 창을 열어 두지 않아도 됩니다. PC가 켜져 있고 Windows에 로그인돼 있을 때만 돌며, 근무 시간 중에 PC를 켜고 Windows에 로그인하면 그 자리에서 한 번 바로 확인합니다(Claude 로그인과는 무관). 방식은 설치할 때 고릅니다.

| 방식 | 하는 일 |
|---|---|
| 자동 분석(`-Mode auto`) | 새 티켓을 한 건씩 AI가 분석해 내부 메모로 남기고, 메모가 등록되면 Windows 알림 |
| 알림만(`-Mode notify`) | 새 티켓 알림만. AI 실행 없음(사용량 없음) |
| MCP만(`-Mode mcp`) | 알림·예약 작업 없이 MCP 연결만 |

백그라운드 AI는 티켓 조회, 분석 잠금, 내부 메모 등록, 등록한 소스 폴더 읽기만 합니다(상태·담당자 변경, 고객 댓글, PowerShell 실행, 파일 쓰기 없음). 끄려면 `/cs:stop`, 자세한 사용법은 `/cs:help`.

설치·업데이트는 CS Center > MCP 연결 관리 화면의 문장을 Claude에 붙여 넣으면 `install.ps1`이 순서대로 처리합니다. 이미 MCP가 연결된 PC는 PowerShell에서 아래 한 줄로도 됩니다.

```
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/leemaroemfocuse/emfocus-cs-plugin/main/install.ps1)))
```
