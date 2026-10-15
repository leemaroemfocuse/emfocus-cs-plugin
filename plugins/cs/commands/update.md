---
description: CS 플러그인 업데이트. 인자 - once(업데이트) | skip(이번 버전 건너뜀)
argument-hint: "once|skip"
---

인자: `$ARGUMENTS`. PowerShell로 실행하고 결과를 한두 줄로 알린다. `$cs`는 `$env:LOCALAPPDATA\CsCenter`, `$mp`는 `$env:USERPROFILE\.claude\plugins\marketplaces\emfocus-cs`다. `claude`가 PATH에 없으면 `%APPDATA%\Claude\claude-code\*\*\claude.exe` 중 가장 최근 것을 쓴다.

- `once`: `claude plugin marketplace update emfocus-cs; claude plugin update cs@emfocus-cs -s user`. 끝나면 "Claude를 다시 열면 적용됩니다"라고 알린다.
- `skip`: `Set-Content "$cs\skipped-sha.txt" (git -C $mp rev-parse origin/main)`. 이 버전은 다시 묻지 않고, 더 새 버전이 나오면 다시 묻는다.
- 인자가 없으면 위 두 가지를 알려 준다. 자동 업데이트는 지원하지 않는다(새 버전마다 바뀐 내용을 보고 고른다).
