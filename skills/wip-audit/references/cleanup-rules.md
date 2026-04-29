# Cleanup Rules — 플랜 분류·검증 + 즉시 실행 가이드

이 문서는 `/wip-audit` 의 Stage 2 (TRIAGE) 와 Stage 4 (EXECUTE) 가 따라야 하는 룰의 단일 근거.

## 1. Per-project window 규칙

각 프로젝트의 마지막 commit 일자(`git log -1 --format=%cs`)를 기준으로 **3일 윈도우**를 계산.

```
window = [last_commit - 3 days, last_commit]
```

플랜 파일이 `classify-plan.sh` 결과로 매칭된 프로젝트의 윈도우 안에 있으면 "활성 가능성 있음", 밖에 있으면 "오래됨 → 정리 후보".

**unknown으로 분류된 플랜**: 플랜 mod date가 *어떤* 프로젝트의 윈도우라도 들어가면 보존 (보수적). 모든 윈도우 밖이면 정리 후보.

## 2. 플랜 완료 검증 (status 결정)

각 플랜에 대해 4가지 상태 중 하나로 분류:

### `completed` — 삭제 후보
플랜이 약속한 *대다수의 substantive change* 가 실제 코드/파일에 반영됨. 기준:
1. 플랜의 "Critical files" / "핵심 파일" / "변경 파일" / "Steps" 섹션을 읽고 약속된 파일 경로를 추출
2. 그 파일들이 실제로 존재하는가? (Read / `ls` / `test -f`)
3. 약속된 코드 스니펫·함수·테이블·필드가 grep으로 잡히는가?
4. 매칭되는 commit이 git log 에 있는가? (`git log --since=<plan_date - 5d> --grep=<keyword>`)

위 4개 중 3개 이상 충족 시 `completed`.

### `in-progress` — 보존
플랜의 일부만 구현됨 (예: Phase A 완료, Phase B 미착수). 보존하고 사용자에게 다음 단계 안내.

### `awaiting-external` — 보존
플랜이 명시적으로 외부 액션(사용자 데이터 export, 외부 PR 머지, 인증 발급 등)을 기다리는 상태. 보존.

### `unknown` — 보수적 보존
짧은 시간 내에 판단 못 함. 보존하고 다음 주에 재평가.

## 3. 즉시 처리 가능 분류 (Stage 4 후보)

**머지 가능한 feature 브랜치**:
- main 이 0 commits ahead (diverge 없음)
- merge-tree 결과 충돌 없음
- feature 브랜치 이름이 명확 (refactor/, feat/, fix/) — WIP 형 브랜치는 제외

**작은 uncommitted 변경**:
- 변경 파일 ≤5개 AND
- 변경이 mechanical (rename, delete, format-only 또는 명백한 사소한 fix)
- 또는 git status 가 단순 untracked 보호용 추가 (CLAUDE.md, scripts/ 등)

**복잡한 잔여 작업으로 분류** (handoff 대상):
- uncommitted ≥6 파일
- 미머지 브랜치 + 다른 변경 혼재
- Phase 다단계 플랜 (Phase B/C/D 등 의존 관계 있음)
- 외부 영향이 큰 변경 (force-push 필요, 보안 이슈 등)

## 4. 안전 가드

- **삭제는 무조건 user 확인 후만**: AskUserQuestion으로 카테고리 선택 받음. 자동 삭제 금지.
- **commit 은 repo 별로 1번씩 확인**: 한 번에 여러 repo 의 commit 일괄 실행 금지.
- **Push 는 별도 단계**: commit 했어도 push 는 사용자가 명시 요청해야.
- **Force-push, history rewrite 류는 무조건 handoff** (Stage 4 자동 실행 대상 아님).
- **불확실하면 KEEP**: 한 번 더 확인하는 비용은 작고, 잘못 삭제한 비용은 큼.

## 5. 입력 데이터 활용

- `~/Codes/.dev-log/` 의 최근 5개 파일은 *참고용*. 플랜 분류 결정에는 우선순위 낮음 (이미 git log + 코드 상태가 더 정확). 단, "어떤 작업을 했었지?" 같은 사용자 회상 도와줄 때 유용.
- BizRouter / Anthropic API 사용 — 우선순위 정책 (`~/.claude/CLAUDE.md` 또는 `MEMORY.md` 참조) 그대로 따름.
