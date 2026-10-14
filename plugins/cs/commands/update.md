---
description: CS 플러그인 업데이트 방식 선택·업데이트. 인자 - once(업데이트) | skip(이번 버전 건너뜀) | auto(자동 업데이트) | ask(앞으로 물어봄)
argument-hint: "once|skip|auto|ask"
---

인자: `$ARGUMENTS`. PowerShell로 실행하고 결과를 한두 줄로 알린다. `$cs`는 `$env:LOCALAPPDATA\CsCenter`, `$mp`는 `$env:USERPROFILE\.claude\plugins\marketplaces\emfocus-cs`다.

- 업데이트 실행(once·auto 공통): `claude plugin marketplace update emfocus-cs; claude plugin update cs@emfocus-cs -s user`. 끝나면 "Claude를 다시 열면 적용됩니다"라고 알린다.
- `once`: 업데이트만 실행한다. 방식은 바꾸지 않는다(다음 새 버전도 물어봄).
- `skip`: `Set-Content "$cs\skipped-sha.txt" (git -C $mp rev-parse origin/main)`. 이 버전은 다시 묻지 않고, 더 새 버전이 나오면 다시 묻는다.
- `auto`: `Set-Content "$cs\update-mode.txt" auto` 후 업데이트를 실행하고 `& "${CLAUDE_PLUGIN_ROOT}/scripts/auto-update.ps1"`로 자동 업데이트를 켠다. 앞으로는 묻지 않고 받으며, 업데이트되면 다음 세션 시작 때 바뀐 내용을 모아 알린다.
- `ask`: `Set-Content "$cs\update-mode.txt" ask` 후 `& "${CLAUDE_PLUGIN_ROOT}/scripts/auto-update.ps1"`로 자동 업데이트를 끈다.
- 인자가 없으면 지금 방식(`update-mode.txt`, 없으면 ask)과 위 선택지를 알려 준다.
