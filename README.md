# EMFOCUS CS Center 자동 유지보수 플러그인

CS Center 새 티켓을 근무 시간(09:30~18:30)에 5분마다 확인해 Windows 알림을 띄우고, 한 건씩 분석해 내부 메모로 남깁니다.

설치·업데이트는 CS Center > MCP 연결 관리 화면의 문장을 Claude에 붙여 넣으면 `install.ps1`이 순서대로 처리합니다. 이미 MCP가 연결된 PC는 PowerShell에서 아래 한 줄로도 됩니다.

```
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/leemaroemfocuse/emfocus-cs-plugin/main/install.ps1)))
```
