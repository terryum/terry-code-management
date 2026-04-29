---
name: code-audit
description: |
  통합 코드베이스 감사 entry point. 인자 없이 호출되면 wip-audit + security-audit 을
  순차 실행. 인자 ('보안 점검', 'WIP 정리', '주간 정리', '리팩토링 대상 찾아줘' 등) 가
  있으면 해당 sub-audit 만 실행. '/code-audit', '코드 감사', '코드 점검', '전체 점검',
  'audit', '점검해줘', 'check up', '코드 상태', '뭐 해야 하지', 'WIP 정리', '주간 정리',
  '보안 점검', '시크릿 스캔' 등 시 반드시 이 스킬을 사용. 확장 가능한 라우터 —
  새 감사 유형이 추가되면 라우팅 표만 갱신하면 된다. 단일 repo 내부 작업이나
  특정 파일 리뷰는 이 스킬 대상 아님.
---

# /code-audit — 통합 코드베이스 감사 라우터

여러 종류의 코드베이스 감사 (위생, 보안, 리팩토링 후보 등) 를 하나의 entry point 로 통합. 사용자가 매번 어떤 sub-skill 인지 결정할 필요 없이 자연어로 의도만 표현.

## 라우팅 표

| Sub-audit | 트리거 키워드 | 실행 방법 | 상태 |
|---|---|---|---|
| **wip-audit** | WIP, 잔여 작업, 주간, 위생, 플랜, 부스러기, 정리, dead plan, 멈췄지, 남은 일 | `Skill(wip-audit)` | ✅ available |
| **security-audit** | 보안, security, 시크릿, secret, 키 노출, 취약점, gitleaks, OSV, sensitive | `Skill(security-audit)` | ✅ available |
| **refactor-audit** | 리팩토링, 긴 파일, 무거운, 복잡, 큰 폴더, 파일 너무 길어, 파일 사이즈 | (미구현) | 🚧 placeholder |
| **doc-audit** | 문서, 설명서, stale README, 문서 빠진, 문서 검사 | (미구현) | 🚧 placeholder |
| **dup-audit** | 중복 코드, duplicate, 같은 코드 | (미구현) | 🚧 placeholder |

## 동작 모드

### Mode A — 인자 없음 (기본)
사용자가 `/code-audit` 만 입력 또는 "전체 점검해줘" 등 폭넓은 표현:

1. `Skill(wip-audit)` 실행 → 5단계 흐름 끝까지 (사용자 confirm 까지 포함)
2. 그 다음 `Skill(security-audit)` 실행 → 5단계 흐름 끝까지
3. 마지막에 두 결과의 짧은 합계 (예: "WIP: 3개 정리됨, Security: 2 HIGH 발견")

**왜 순차**: 두 감사가 독립적이지만 wip-audit 이 main 정리(commit/push)를 하기 때문에 security 가 깨끗한 상태에서 검사하는 게 정확.

### Mode B — 명시적 sub-audit
사용자가 특정 키워드 포함:
- "보안 점검", "시크릿 스캔" → `Skill(security-audit)` 만
- "WIP 정리", "주간 정리", "플랜 정리", "부스러기" → `Skill(wip-audit)` 만
- 명시적 + 추가 키워드 → 매칭되는 모든 sub-audit (예: "WIP + 보안 둘 다")

### Mode C — 미구현 sub-audit 요청
"리팩토링 필요한 파일 찾아줘", "stale 문서 찾아줘" 같이 위 라우팅 표의 🚧 카테고리:

응답 예:
```
🚧 'refactor-audit' 은 아직 구현 안 돼 있습니다. 다음 중 선택해주세요:

1. 직접 만들어 드릴까요? (`harness` 스킬로 새 sub-audit 생성)
2. 비슷한 기능을 임시로 수행 (예: find -size +50k 같은 단순 명령)
3. 다른 sub-audit 으로 대신 (weekly / security)
```

## 라우팅 결정 규칙

순서대로 적용:

1. 사용자 메시지에 라우팅 표의 트리거 키워드가 있는지 grep
2. 매칭되는 키워드가 1개 이상이면 해당 sub-audit(들) 실행 (Mode B)
3. 매칭 0개이고 메시지가 빈 인자 또는 폭넓은 표현 ("전체", "다", "모두", "audit") 이면 Mode A (default 순차 실행)
4. 매칭 0개이고 미구현 카테고리 키워드 ("리팩토링", "문서 검사" 등) 가 있으면 Mode C
5. 그 외 — 사용자에게 "어떤 감사를 하실까요?" 묻기 (AskUserQuestion 으로 옵션 제시)

## 사용 예시

```
> /code-audit
[Mode A: wip-audit 실행 → security-audit 실행 → 합계]

> /code-audit 보안 점검해줘
[Mode B: security-audit 만]

> /code-audit WIP 정리하고 보안도 같이
[Mode B: 둘 다 — 명시적]

> /code-audit 리팩토링 필요한 프로젝트 찾아줘
[Mode C: 🚧 미구현 안내 + 옵션 제시]
```

## 새 sub-audit 추가하는 법

1. `harness` 스킬로 새 skill 생성 (예: `refactor-audit`)
2. `~/Codes/terry-code-management/skills/<name>/` 에 SKILL.md + scripts + references
3. `./install.sh` 실행 → `~/.claude/skills/<name>` 심링크 생성
4. **이 SKILL.md 의 라우팅 표** 에 한 줄 추가:
   - sub-audit 이름
   - 트리거 키워드 5-7개
   - 상태 ✅ 로 변경
5. 끝. `Skill(<name>)` 으로 호출 가능.

## 트리거 매칭 가이드

✅ 이 스킬을 사용:
- "/code-audit", "코드 감사", "전체 점검", "점검해줘", "audit"
- "WIP 정리", "주간 정리", "보안 점검" (sub-skill 직접 호출보다 이쪽이 우선)
- "내 코드 상태 어때", "정리할 게 뭐 있어"

❌ 다른 도구 사용:
- "이 PR 리뷰" → `/review` 또는 `/security-review`
- "이 함수 리팩토링" → 직접 코드 수정
- "git status 한 번만" → bash 직접

## 안전 가드

- 모든 sub-audit 의 안전 가드는 그대로 적용 (commit/delete 는 사용자 confirm 후만)
- 두 sub-audit 을 순차 실행할 때, 첫 audit 의 사용자 confirm 단계는 두 번째로 넘어가기 전에 반드시 완료
- 어느 sub-audit 이라도 실패하면 다음으로 진행하지 말고 사용자에게 보고
- 미구현 sub-audit 요청 시 절대 fallback 으로 임의 실행 금지 — 명시적 선택 받기

## 참고

- 각 sub-audit 의 자세한 동작은 `~/.claude/skills/<name>/SKILL.md` 참고
- 라우팅 표가 길어지면 `references/routing.md` 로 분리 (현재는 SKILL.md 내 인라인)
