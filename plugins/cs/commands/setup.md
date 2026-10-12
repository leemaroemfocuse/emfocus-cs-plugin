---
description: 내 CS 프로젝트별 로컬 소스 위치를 찾아 ~/.claude/cs-knowledge/projects.md 에 저장합니다
---

개발자마다 소스 위치가 다르므로 이 PC 기준으로 한 번 정리한다. 이후 /cs:run 은 이 파일만 보고 소스를 찾는다.

1. 내 프로젝트 목록: `get_my_projects`가 있으면 쓰고, 없으면 `get_my_project_ticket_summary(hours=168)`를 쓴다.
2. 프로젝트마다 `get_project_domain_knowledge`의 문서에서 프로필명·소스 경로·저장소 이름 단서만 뽑는다(본문 전체를 옮기지 않는다).
3. 로컬 저장소 후보: `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/find-sources.ps1"`.
4. 단서(프로필명, 저장소 이름, 고객사 영문 약어)와 폴더명을 대조해 프로젝트별 소스 경로를 정한다.
   - git 저장소를 작업 소스로 우선한다. svn 사본은 "비교 전용"으로 따로 적고 수정 대상으로 쓰지 않는다.
   - 확신이 없으면 후보를 보여주고 사용자에게 고르게 한다. 사용자가 없는 실행(-p)이면 `미확인`으로 둔다.
5. `~/.claude/cs-knowledge/projects.md`를 아래 형식으로 쓴다(기존 파일이 있으면 사용자가 직접 적은 경로는 유지하고 빈 칸만 채운다):

```
# CS 프로젝트 로컬 소스 (이 PC 전용)
| projectId | 고객사 | 프로젝트 | 작업 소스 | 비교 전용 | 근거 | 확인일 |
| --- | --- | --- | --- | --- | --- | --- |
```

6. 결과를 표로 보여주고, 미확인 프로젝트가 있으면 경로를 알려달라고 한 줄로 요청한다.
