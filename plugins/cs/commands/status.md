---
description: CS 자동 유지보수가 도는지, 최근 결과를 보여줍니다
---

PowerShell로 `Get-ScheduledTask -TaskName "CS 자동 유지보수"`와 `Get-ScheduledTaskInfo`의 State, LastRunTime, NextRunTime을 확인하고, `%LOCALAPPDATA%\CsCenter\cs-auto.log`의 마지막 20줄을 읽어 다음을 3줄 이내로 알린다: 켜짐/꺼짐, 마지막·다음 실행 시각, 최근 처리한 티켓(없으면 "최근 처리 없음"). 작업이 없으면 "꺼져 있음. 켜려면 /cs:start".
