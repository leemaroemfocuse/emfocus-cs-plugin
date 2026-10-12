---
description: CS 자동 유지보수 사용법
---

아래 내용을 그대로 출력하고 다른 도구는 호출하지 않는다.

```
/cs:run            내 프로젝트의 접수·재오픈 티켓 1건을 가져가 분석 → [AI 자동 분석] 내부 메모
/cs:run 3          3건
/cs:run all        전체(최대 100)
/cs:run 2 project=12   프로젝트 12만

가져가는 순간 본인 담당·진행으로 바뀌어 다른 사람과 겹치지 않음.
끊겨도 다음 실행에서 메모 없는 티켓을 먼저 이어서 처리함(세션을 새로 열어도 됨).
소스·DB·상태·고객 댓글은 건드리지 않음. 메모 검토 후 개발은 직접 지시.

/cs:start [분] [project=ID]   예약 실행 켜기(창 없이 Windows 로그인 상태면 계속 돔, 기본 30분)
/cs:stop                      예약 실행 끄기
/cs:status                    도는지, 최근 결과 확인
필요 권한: ticket.assign.self, ticket.status, ticket.internal_note (Full 토큰)
```
