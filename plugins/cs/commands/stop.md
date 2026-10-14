---
description: CS 자동 유지보수 예약 실행을 끕니다
---

PowerShell로 다음을 실행한다. 꺼 둔 표시(`stopped.txt`)를 남겨 Claude를 다시 열어도 다시 등록되지 않게 한다.
`New-Item -ItemType Directory -Force "$env:LOCALAPPDATA\CsCenter" | Out-Null; Set-Content "$env:LOCALAPPDATA\CsCenter\stopped.txt" (Get-Date -Format s); Unregister-ScheduledTask -TaskName "CS 자동 유지보수" -Confirm:$false -ErrorAction SilentlyContinue`
 작업이 없으면 "이미 꺼져 있음"이라고 한 줄로 알린다. 끝나면 "자동 유지보수를 껐습니다. 다시 켜려면 /cs:start"라고 한 줄로 알린다.
