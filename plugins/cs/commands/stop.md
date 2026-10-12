---
description: CS 자동 유지보수 예약 실행을 끕니다
---

PowerShell로 `Unregister-ScheduledTask -TaskName "CS 자동 유지보수" -Confirm:$false`를 실행한다. 작업이 없으면 "이미 꺼져 있음"이라고 한 줄로 알린다. 끝나면 "자동 유지보수를 껐습니다. 다시 켜려면 /cs:start"라고 한 줄로 알린다.
