---
name: weekly-audit
description: |
  /Codes 하위 모든 프로젝트의 위생 점검 — 진행 중/중단/계획만 있는 작업을 파악하고,
  이미 완료된 dead plan 삭제, 즉시 가능한 작은 commit/push 처리, 복잡한 잔여 작업은
  해당 폴더로 이동할 수 있도록 핸드오프 프롬프트 생성. '주간 정리', '/weekly-audit',
  '뭐하다 멈췄지', '남은 일 뭐 있어', '코드 상태 점검', '플랜 정리', '부스러기 정리',
  '뭐 해야 하지', 'audit 해줘', 'housekeeping', 'status check' 시 반드시 이 스킬 사용.
  주간 1회 정기 호출 용도. 단일 repo 작업이나 단일 plan 검증은 이 스킬 대상 아님.
---

# /weekly-audit — 주간 코드베이스 위생 점검

매주 한 번, 사용자의 모든 프로젝트 상태를 한 번에 파악하고 부스러기를 정리하는 스킬.

## 목적

사용자가 여러 프로젝트를 병행하다 보면:
- 어떤 repo 에서 어디까지 했는지 잊는다
- 완료된 작업의 plan 파일이 ~/.claude/plans/ 에 부스러기로 쌓인다
- 작은 uncommitted 변경이 묵혀진다
- 복잡한 잔여 작업은 해당 폴더로 직접 가서 마무리해야 한다

이 스킬은 위 4가지를 한 흐름으로 처리한다.

## 5단계 워크플로우

### Stage 1 — SCAN (read-only, 자동)

데이터를 한 번에 수집한다 (atomic gather):

```bash
bash ~/.claude/skills/weekly-audit/scripts/scan-projects.sh
bash ~/.claude/skills/weekly-audit/scripts/scan-plans.sh
```

추가로 dev-log 최근 활동 파악 (참고용):
```bash
ls -t ~/Codes/.dev-log/2026-*.md 2>/dev/null | head -5
```

**산출물 (메모리 내 보관)**:
- 각 프로젝트의 last commit / branch / uncommitted / feature branches / stash
- 모든 plan 파일의 (date, name, size, title)
- 최근 5일 dev-log 메타정보

### Stage 2 — TRIAGE (분류, 자동)

각 발견 사항을 4개 카테고리로 분류한다. 분류 룰은 `references/cleanup-rules.md` 참조.

**플랜 분류** (각 플랜에 대해):
1. `bash scripts/classify-plan.sh <plan_file>` 으로 프로젝트 매핑
2. 프로젝트의 마지막 commit 일자로 3일 윈도우 계산
3. 플랜이 약속한 파일·코드 변경이 실제 존재하는지 확인 (Read + Grep + git log)
4. 결과 status: `completed` (삭제 후보) / `in-progress` (보존) / `awaiting-external` (보존) / `unknown` (보수적 보존)

**즉시 처리 가능 후보**:
- 머지 가능한 feature 브랜치 (충돌 없고 main 0 commits ahead)
- 작은 uncommitted (≤5 파일, mechanical change)

**복잡한 잔여 작업**:
- uncommitted ≥6 파일
- Phase 다단계 플랜 (Phase B/C/D 등)
- force-push / 보안 / 외부 영향 큰 변경

플랜이 30개 이상이면 분류는 sub-agent (general-purpose) 에 위임 — 병렬 처리 + main context 보호.

### Stage 3 — REPORT (사용자 한 번에 제시)

`references/report-format.md` 형식으로 4개 표 출력:
- 🔴 즉시 처리 가능 (Here)
- 🟢 Dead plan 삭제 후보 (with 검증 evidence)
- 🟠 복잡한 잔여 작업 (handoff 프롬프트는 Stage 5 에서 출력)
- 🟡 정상 진행 중 (참고용)

표 자체는 스캔 가능하게 슬림하게. 한 화면에 들어가도록.

### Stage 4 — EXECUTE (사용자 confirm 후만)

AskUserQuestion 으로 카테고리 선택:
1. dead plan 삭제만
2. 작은 commit 실행만
3. 둘 다 (recommended)
4. 아무것도 (리포트만 보고 끝)

선택된 카테고리에 따라:
- **Dead plan 삭제**: 한 번에 batched `rm` (몇 개인지 명시 후 실행)
- **작은 commit**: repo 별로 분리 실행. commit 메시지는 `chore(repo): <한 줄 설명>` 형식. **push 는 별도 사용자 요청이 있을 때만**.

각 단계 실행 후 한 줄 progress 메시지. 에러 발생 시 즉시 중단하고 사용자에게 보고.

### Stage 5 — HANDOFF (항상 마지막에)

`references/handoff-template.md` 형식으로 복잡한 잔여 작업 각각에 대해:
- `cd <absolute path>` 명령
- 복사 붙여넣기용 self-contained 프롬프트
- 관련 plan 파일 경로 (있으면)
- 우선순위 (긴급 / 중요 / 일반)

사용자가 새 세션을 해당 폴더에서 시작할 때 바로 사용할 수 있게.

## 중요 가드

- **삭제는 무조건 user 확인 후만**. AskUserQuestion 없이 자동 삭제 금지.
- **Push 는 commit 과 분리**. commit 했어도 push 는 사용자 명시 요청 필요.
- **Force-push, history rewrite 류는 자동 실행 대상 아님** — 무조건 handoff 로.
- **불확실하면 KEEP**. 한 번 더 확인 비용은 낮고, 잘못 삭제 비용은 높음.
- **두 개 이상 repo 를 동시에 commit 하지 말 것**. 한 번에 한 repo.

## 트리거 매칭 가이드 (오작동 방지)

✅ **이 스킬을 사용**:
- "주간 정리", "/weekly-audit", "뭐 해야 하지", "남은 일 뭐 있어"
- "코드베이스 상태 점검", "audit 해줘", "플랜 정리", "부스러기 정리"
- "뭐하다 멈췄지", "현재 상태 파악해줘"

❌ **이 스킬 대상 아님**:
- "<특정 repo> 브랜치 정리해줘" → 직접 git 명령
- "git status 보여줘" → 단일 명령으로 충분
- "이 함수 리팩토링" → 코드 수정 작업
- "오늘 뭐했지" → dev-log 단순 조회 (이 스킬은 5일 범위)
- "특정 plan 파일 읽어줘" → Read 툴 직접 사용

## 데이터 소스 위치

- 프로젝트 루트: `$CODES_ROOT/<group>/<repo>/` (기본값 `~/Codes/`, 그룹은 자동 discover)
- 플랜: `~/.claude/plans/*.md`
- dev-log: `$CODES_ROOT/.dev-log/*.md` (있는 경우)
- 글로벌 룰: `~/.claude/CLAUDE.md`, `~/.claude/projects/.../memory/MEMORY.md`

스크립트는 하드코딩된 그룹·레포명 없이 동작 — 모두 파일시스템 스캔으로 발견.

## 출력 형식 일관성

매 주 같은 4개 표 (헤더 동일, 컬럼 동일) 로 출력. 그래야 사용자가 주간 변화를 쉽게 파악할 수 있음.

스킬 내부 처리는 자유롭게 하되, 사용자가 보는 최종 출력은 `references/report-format.md` 에 박아둔 템플릿 그대로 따른다.

## 실패 시 graceful degradation

- plan 파일 0개 → "정리할 플랜 없음" 한 줄 + 다른 카테고리 그대로 진행
- 모든 repo 클린 + plan 도 없음 → "모든 게 깨끗함, 즉시 처리할 작업 없음" + Stage 5 (handoff) skip
- 일부 repo 의 git 명령 실패 → 그 repo 만 skip + 보고서에 표시 (`⚠ scan failed`)
- 30 초 안에 scan 완료 안 되면 그 시점까지 결과로 진행 (멈추지 말 것)

## 참조 문서

- `references/cleanup-rules.md` — 분류 + 검증 + 안전 룰의 단일 근거
- `references/report-format.md` — Stage 3 출력 템플릿
- `references/handoff-template.md` — Stage 5 출력 템플릿
- `scripts/scan-projects.sh` — 프로젝트 git 상태 수집
- `scripts/scan-plans.sh` — 플랜 파일 메타데이터 수집
- `scripts/classify-plan.sh` — 단일 플랜 → 프로젝트 매핑

## 검증 체크리스트 (스킬 자체 동작 확인)

새로 호출했을 때 다음이 정상 동작하는지:
1. ✅ Stage 1 SCAN 이 30초 안에 완료
2. ✅ Stage 3 REPORT 가 4개 표 한 화면에 들어감
3. ✅ Stage 4 EXECUTE 는 항상 AskUserQuestion 으로 시작
4. ✅ Stage 5 HANDOFF 는 사용자 선택과 관계없이 항상 출력
5. ✅ plan 파일 0개여도 graceful exit (에러 없이)
