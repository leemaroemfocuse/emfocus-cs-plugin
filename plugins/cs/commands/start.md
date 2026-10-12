---
description: CS 자동 유지보수 예약 실행을 켭니다. 인자 - 간격(분, 기본 5), project=<ID>
argument-hint: "[30] [project=<ID>]"
---

인자: `$ARGUMENTS`

숫자가 있으면 간격(분), `project=<ID>`가 있으면 프로젝트로 쓴다. 다음을 실행한다:
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/register-task.ps1" -Minutes <간격> [-Project <ID>] -WorkDir "<현재 작업 폴더>"`
결과 한 줄과 로그 위치(`%LOCALAPPDATA%\CsCenter\cs-auto.log`)를 알린다.
