# Report Format — 사용자에게 보여줄 4-카테고리 표

Stage 3 (REPORT) 출력 템플릿. 모든 표는 한 화면에 들어가도록 슬림하게.

## 헤더

```
🔍 주간 코드베이스 감사 — <today_date>
스캔된 repo: N개 / 플랜 파일: M개 / dev-log 최근 활동: <YYYY-MM-DD ~ YYYY-MM-DD>
```

## 🔴 즉시 처리 가능 (Here)

| Repo | 작업 | 영향 |
|---|---|---|
| `<repo-A>` | feature 브랜치 머지 (refactor/X → main) | N commits 정리 |
| `<repo-B>` | 작은 cleanup 커밋 | 머지 불필요 |
| `<repo-C>` | 이미지 1개 표준 spec 적용 | 2.2MB → 130KB |

→ Stage 4 에서 사용자 confirm 후 실행.

## 🟢 Dead Plan 삭제 후보

| 날짜 | 플랜명 | 검증 evidence (1줄) |
|---|---|---|
| YYYY-MM-DD | `<plan-slug>` | commit `<sha>` + 약속 파일 X 존재 |
| ... | ... | ... |

→ Stage 4 에서 일괄 삭제 가능.

## 🟠 복잡한 잔여 작업 (Handoff)

각 항목마다 핸드오프 프롬프트 동봉 (`references/handoff-template.md` 형식).

```
[1] <repo-A> — <task name>
   📁 cd $CODES_ROOT/<group>/<repo-A>
   📋 (프롬프트는 handoff-template.md 형식대로)
   상태: Phase X 완료 / Phase Y 진행 중

[2] <repo-B> — <task name>
   📁 cd $CODES_ROOT/<group>/<repo-B>
   📋 (긴급 — force-push 필요)
   상태: Phase X / Y 진행 중
```

## 🟡 정상 진행 중 (참고만)

활성 윈도우 안에 있고 완료되지 않은 플랜은 여기에 한 줄씩.

```
- <repo-A> — <plan title> (다음 단계 대기)
- ...
```

## 마무리 액션 메뉴

AskUserQuestion 으로:
1. dead plan 삭제만
2. 작은 commit 실행만
3. 둘 다 (recommended)
4. 아무것도 (리포트만 봄)

선택 후 Stage 4 진입. Stage 5 의 handoff 프롬프트는 항상 마지막에 출력 (사용자가 다른 폴더로 이동할 때 복사 가능).
