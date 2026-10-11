# Claude Code 스킬 인벤토리 → Codex 포팅 가이드

생성일: 2026-05-12
대상: Codex에서 Claude Code 동작과 동일/유사한 스킬 시스템을 구축하려는 에이전트·개발자

---

## 0. 이 문서의 목적

사용자 `terry.t.um@gmail.com` 의 Claude Code 환경에는 **글로벌 스킬 8개 + 플러그인 스킬 ~150개 + 프로젝트 스킬 59개 + harness-100 템플릿 630개**가 깔려 있다. Codex에서 같은 시스템을 만들기 전에:

1. 어떤 스킬이 있고 무엇을 하는지 한 곳에서 파악
2. 어떤 스킬이 Codex 강점(긴 컨텍스트, 코드 생성)과 맞는지, 어떤 게 외부 의존성 때문에 그대로 옮기기 어려운지 구분
3. 시스템 메커니즘(frontmatter, trigger, symlink, sub-skill, agent team) 이해

**우선순위 추천은 의도적으로 비워둠** — 객관 정보만 제공하고 사용자가 직접 결정.

---

## 1. Claude Code 스킬 시스템 메커니즘 (Codex 측 컨텍스트)

### 1.1 발동 경로 (두 가지)

| 경로 | 트리거 | 예시 |
|---|---|---|
| **명시적 호출** | `/skill-name` 슬래시 명령 또는 `Skill` 툴 호출 | `/survey --orchestrate` |
| **Description 트리거** | 사용자 자연어가 SKILL.md `description` 첫 문장의 트리거 키워드와 매칭 | "글 써줘" → `write`, "태그 달아줘" → `tagging` |

**중요**: description 트리거는 `/Skill` 호출 카운트에 잡히지 않는다. 따라서 "호출 0회" ≠ "안 쓰는 스킬"이다.

### 1.2 SKILL.md frontmatter 규약

```markdown
---
name: <skill-name>            # /<skill-name> 으로 호출됨
description: "한 문장에 트리거 키워드를 자연스럽게 녹여 쓴다. 'X 요청 시 사용' 형태로 끝나는 경우가 많다."
argument-hint: "<arg1> [--flag1] [--flag2=val]"   # 선택, 슬래시 명령 자동완성용
---

# Body — 스킬이 실제로 무엇을 하는지의 본문
```

대소문자: 글로벌·프로젝트 스킬 모두 `SKILL.md` 가 표준. 일부 오래된 스킬은 `skill.md` (소문자) — 표기는 통일이 안 됨.

### 1.3 Canonical source + symlink 패턴

같은 스킬을 여러 프로젝트에서 쓰고 싶을 때, 한 곳에 정의하고 다른 곳에서는 symlink:

```
~/Codes/personal/terryum-ai/site/.claude/skills/defuddle/SKILL.md  ← canonical
~/Codes/personal/context/terry-obsidian/.claude/skills/defuddle       → symlink
~/Codes/personal/terryum-ai/terry-surveys/framework/.claude/skills/defuddle        → symlink
~/Codes/personal/terryum-ai/terry-papers/.claude/skills/defuddle         → symlink
```

글로벌 스킬도 일부는 프로젝트로의 symlink로 운영된다 (`~/.claude/skills/cite-post` → `~/Codes/personal/terryum-ai/terry-surveys/framework/.claude/skills/cite-post`).

**Codex 포팅 시 주의**: 단순 파일 복사로 포팅하면 canonical 갱신이 전파되지 않음. Codex 측이 symlink를 지원하는지, 아니면 빌드 시 동기화 스크립트가 필요할지 결정 필요.

### 1.4 Sub-skill / 라우터 패턴

스킬이 다른 스킬을 호출:

```
code-audit (라우터)
  ├─> wip-audit (WIP/plan 정리)
  └─> security-audit (secret/취약점 스캔)
```

라우터 스킬은 인자에 따라 sub-skill을 골라 실행한다. Codex에서 같은 패턴을 구현하려면 "스킬 → 스킬" 호출이 가능한 런타임이 필요.

### 1.5 멀티에이전트 오케스트레이션

가장 무거운 스킬들은 단순 트리거가 아니라 **에이전트 팀**을 구성한다. Claude Code의 기본 툴 `TeamCreate + SendMessage + TaskCreate` 을 활용:

- `survey --orchestrate` → 7 에이전트 (deep-researcher-foundations, deep-researcher-frontier, critical-analyst, book-writer, image-curator, fact-checker, qa-reviewer)
- `cosmax-esg-orchestrator` → 4 에이전트 (writer, fact-checker, researcher, image-curator)
- `book-write` (terry-facebook-pull) → drafter + 3 readers + critic + editor + reviser
- `build-radar` (physical-ai-news) → crawler + curator + UI builder + deployer
- `kis-dashboard-orchestrator` (terry-stock) → 7 에이전트 (Architect/Backend/Frontend/Asset-Intelligence/Market-Intelligence/Security/QA)

에이전트 정의는 `<project>/.claude/agents/*.md` 또는 `surveys/<slug>/.claude/agents/*.md`에 있다.

**Codex 포팅 시 핵심 질문**: Codex가 `TeamCreate` 류의 멀티 에이전트 런타임을 갖고 있는가? 없으면 이 스킬들은 직렬화/단일 에이전트 버전으로 새로 설계해야 한다.

### 1.6 자동화: hooks vs skills

스킬은 "사용자가 부르면 실행"되는 패시브 자원. "X 가 일어나면 자동으로 Y 한다" 는 hooks (`~/.claude/settings.json`)로 처리. 예: SessionEnd hook → 데브로그 자동 작성. Codex 측에도 비슷한 이벤트 훅 모델이 있어야 일부 워크플로우가 재현 가능.

---

## 2. 글로벌 스킬 카탈로그 (`~/.claude/skills/`, 8개)

심볼링크 4개 + 직접 디렉토리 4개. 모두 사용자 작성.

| 스킬 | 위치 | 한 줄 설명 | 외부 의존성 | 30일 호출 |
|---|---|---|---|---|
| `image-gen` | 직접 | OpenAI 이미지 생성 API로 이미지 생성, 스타일 프리셋·Pillow 리사이즈 | OpenAI API (`OPENAI_API_KEY`), Python/Pillow | 15회 (다수 스킬이 sub-call) |
| `whytree` | 직접 | Why Tree 기법 기반 목적 발견 세션, 27K 본문 + 20+ 참조 문서 | Python, `~/.whytree/` 상태 디렉토리 | 0회 |
| `harness` | 직접 | 메타 스킬 — 새 도메인을 위한 에이전트·스킬을 자동 생성/갱신 | `.claude/agents/`, `.claude/skills/`, `CLAUDE.md` 강결합 | 2회 |
| `pdf-update` | 직접 | 책 마크다운(book/ko, book/en) 변경 후 한국어/영어 PDF 재빌드 | `scripts/build_pdf.sh`, Node `md-to-pdf`, PyMuPDF (선택) | 미측정 |
| `cite-post` | symlink → `terry-surveys` | www.terryum.ai 포스트 번호를 책의 인용·참고문헌에 매칭 | terry-surveys 인덱스 | 0회 |
| `code-audit` | symlink → `terry-code-management` | 통합 코드 감사 라우터 (wip-audit + security-audit 조율) | 라우터 — 자체 의존성 없음 | 0회 |
| `security-audit` | symlink → `terry-code-management` | gitleaks · OSV scanner · 민감 파일 / public 노출 점검 | `gitleaks`, `osv-scanner`, `gh` CLI (모두 선택) | 0회 |
| `wip-audit` | symlink → `terry-code-management` | 진행 중/dead plan 정리, 작은 commit 처리, 핸드오프 프롬프트 생성 | git, `scripts/scan-{projects,plans}.sh` | 0회 |

**Note**: 사용자 정리 기준 (글로벌 중복/대체된 것만 archive)으로 검토했으나 **archive 대상 0개**. 과거의 `gemini-3-image-generation` → `image-gen` 리네임은 이미 정리됨.

---

## 3. 플러그인 스킬

### 3.1 OpenAI Codex 플러그인 (`codex@openai-codex` v1.0.2)

Codex가 **이미 가진** 것. 새로 포팅할 필요 없음 — 그대로 활용:

| 스킬 | 설명 |
|---|---|
| `codex:setup` | Codex CLI 준비 상태 확인 + stop-time review gate 토글 (사용자 호출 5회) |
| `codex:rescue` | 막혔거나 두 번째 구현/진단/근본 원인 조사가 필요할 때 Codex 구제 서브에이전트로 위임 (사용자 호출 2회) |
| `codex:codex-cli-runtime` | (internal) codex-companion 런타임 호출 컨트랙트 |
| `codex:codex-result-handling` | (internal) Codex 출력 결과를 사용자에게 다시 표시하는 가이드 |
| `codex:gpt-5-4-prompting` | (internal) Codex / GPT-5.4 프롬프트 구성 가이드 (코딩·리뷰·진단·리서치) |

### 3.2 Vercel 플러그인 (`vercel@claude-plugins-official` v0.42.1)

배포·인프라 자동화용. 26개 스킬 (ai-gateway, ai-sdk, auth, bootstrap, chat-sdk, deployments-cicd, env-vars, knowledge-update, marketplace, next-cache-components, next-forge, next-upgrade, nextjs, react-best-practices, routing-middleware, runtime-cache, shadcn, turbopack, vercel-agent, vercel-cli, vercel-firewall, vercel-functions, vercel-sandbox, vercel-storage, verification, workflow).

Codex 측은 Vercel 통합이 있는지에 따라 일부만 이식. 사용자의 실제 배포는 대부분 Cloudflare 기반이라 Vercel 플러그인 사용도는 낮은 편 (마지막 Vercel 감사 2026-04-18에 사용자가 Vercel 참조 모두 제거).

### 3.3 marketplace 카탈로그 (116개)

`~/.claude/plugins/marketplaces/claude-plugins-official/` 아래 hookify, frontend-design, mcp-server-dev, claude-md-management, plugin-dev 등의 플러그인이 포함. 설치된 게 아니라 카탈로그 — Codex가 같은 마켓플레이스 패턴을 둘지는 별개 결정.

---

## 4. 프로젝트 스킬 (59개) — 도메인별 정리

`~/Codes/*/.claude/skills/` 아래. harness-100 템플릿 630개는 100개 시나리오 × 평균 6.3 스킬의 벤치마크 fixture이므로 카탈로그에서 제외.

### 4.1 콘텐츠 발행 파이프라인 — `terry-obsidian` (10) + `terry-papers` (1) + `terryum-ai` (9)

웹사이트 `www.terryum.ai` 의 콘텐츠 생애주기.

| 스킬 | canonical 위치 | 역할 |
|---|---|---|
| `write` | terry-obsidian | Obsidian 글쓰기 5-모드 (메모→초안, 세션 요약, light/heavy 수정, polish, ChatGPT share 요약) |
| `draft` | terry-obsidian | Drafts 폴더에 발행용 초안 생성, 첫 문장이 제목 |
| `post` | terry-obsidian | Drafts → 발행 (essays/notes), `--visibility=public/private/group` |
| `paper` | terry-papers | arXiv·학술지·기술 블로그 URL → Papers 포스트 + 지식그래프 노드. virtual/synthesis 지원 |
| `paper-search` | terryum-ai | GraphRAG-lite 논문 추천 (explore / next 모드) |
| `tagging` | terry-obsidian | Obsidian 글 자동 태깅 |
| `task` | terry-obsidian | 일일 태스크 파일 (롤오버·아카이브·히스토리) |
| `cal` | terry-obsidian | 구글캘린더 자연어 CRUD |
| `create` | terry-obsidian | 템플릿 기반 빈 문서 생성 |
| `obsidian-markdown` | terry-obsidian | Obsidian Flavored Markdown 편집 (wikilinks, callouts, embeds) |
| `obsidian-cli` | terry-obsidian | Obsidian vault CLI 조작 + 플러그인/테마 개발 |
| `obsidian-orchestrator` | terry-obsidian | (internal) 4-agent 팀 통합 빌드 |
| `project` | terryum-ai | Project 갤러리 카드 추가 (GitHub URL/수동) |
| `share` | terryum-ai | Facebook/Threads/LinkedIn/X/Bluesky/Substack 자동 발행 |
| `del` | terryum-ai | 포스트 삭제 (인덱스, R2, Supabase, 참조, Obsidian, 정적 에셋 일괄 정리) |
| `defuddle` | terryum-ai | 웹페이지 클린 마크다운 추출 (WebFetch 대비 토큰 절약) |
| `infra-optimize` | terryum-ai | 코드베이스 리팩토링 + R2 마이그레이션 + Git 정리 (Architect→Engineer→QA) |

**핵심 인프라**: Cloudflare R2 (이미지), Cloudflare Pages (웹사이트), Supabase (비공개 콘텐츠), Obsidian vault, OpenAI Images (이미지 생성).

### 4.2 서베이 책 — `terry-surveys` (15 own + 5 symlinks)

학술 서베이 책의 부트스트랩~집필~배포 모노레포.

| 스킬 | 역할 |
|---|---|
| `survey` | **메인 허브.** MODE A (부트스트랩) + MODE B (등록) + 서브커맨드 (--orchestrate, --sync-agents, --refresh, --factcheck, --link-posts, --deploy). 집필은 기본 `--orchestrate` (7 에이전트 자율 병렬) |
| `survey-lite` | 토큰 효율 최적화 버전 (Sonnet + 챕터별 fresh sub-agent, 비용 40-60% 절감) |
| `book-write` | "Tactile Sensing for Robot Hands" 책 챕터 집필 (12 챕터, 마크다운) |
| `expert-book-write` | 한·영 이중언어 서베이 챕터 집필 (서사 + agentic coding 대비 유지) |
| `research-book-orchestrator` | "LLM Planner → VLA → Agentic Robotics" 서베이 전체 파이프라인 |
| `tactile-book-orchestrator` | "Tactile Sensing" 책 4-Phase 파이프라인 (lit. research → 분석 → 집필 → 웹) |
| `literature-research` | tactile sensing / robot hand / manipulation 분야 문헌 체계 조사 |
| `deep-literature-research` | VLA / LLM 기반 agentic robotics 심층 서베이 + 인용 분석 + 그룹 매핑 |
| `ieee-paper-write` | IEEE T-RO/RA-L/T-ASE 스타일 LaTeX survey paper 작성 |
| `critical-analysis` | 비판적 분석 (gap, limitation, controversy) |
| `fact-check` | 인용·수치·출처 교차 검증 |
| `content-extract` | (도구) 콘텐츠 추출 |
| `curate-paper-images` | 논문에서 figure/table 추출 + 큐레이션 (image-gen 호출) |
| `link-post-to-surveys` | Tier 1 포스트를 서베이에 역링크 |
| `cite-post` | 글로벌과 동일 (canonical 여기) |
| `web-build` | 정적 웹사이트 빌드 (dark/glassmorphism/GSAP/particle, revfactory.github.io 스타일) |

서베이 책 한 권당 `surveys/<slug>/.claude/agents/*.md` 의 7개 에이전트가 자체 조율 — 이 패턴이 가장 복잡한 멀티에이전트 시스템.

### 4.3 책 집필 — `terry-facebook-pull` (3)

| 스킬 | 역할 |
|---|---|
| `book-write` | 3-team 병렬 (drafter + 3 readers + critic + editor + reviser) |
| `book-source-loader` | 소스 자료 로딩 |
| `book-style-context` | 문체·스타일 컨텍스트 |

### 4.4 ESG 전략서 — `cosmax/cosmax-esg-strategy` (6)

| 스킬 | 역할 |
|---|---|
| `cosmax-esg-orchestrator` | 마스터 오케스트레이터 ("책 만들어줘" 트리거) — 4-agent 팀 |
| `cosmax-esg-write` | 9 챕터 한국어 5000-7000자 집필. 1차 참조 SR 2024 + KC 브리핑 2026 |
| `esg-framework-research` | GRI/SASB/TCFD/ISSB/CSRD/K-ESG/MSCI/DJSI/Sustainalytics/KCGS + 화장품/ODM 산업 |
| `esg-fact-check` | 수치·인용·출처·논리 교차 검증, 단위·연도·범위·percentage point |
| `esg-gap-analysis` | 코스맥스 vs 글로벌 리더 정량 격차, Impact×Urgency×Feasibility 매트릭스, 2030 로드맵 |
| `insert-chapter-images` | 9 챕터 이미지 (실제 자료 우선, 개념 일러스트는 Gemini 3 Pro 생성) |

### 4.5 뉴스 큐레이션 — `cosmax/physical-ai-news` (5)

| 스킬 | 역할 |
|---|---|
| `build-radar` | 4-agent 팀 (crawler + curator + UI builder + deployer) |
| `crawl-sources` | 소스 크롤링 |
| `curate-content` | 콘텐츠 큐레이션 |
| `deploy-cloudflare` | Cloudflare Pages 배포 |
| `send-digest` | Substack 다이제스트 발송 |

### 4.6 투자 대시보드 — `terry-stock` (8)

| 스킬 | 역할 |
|---|---|
| `kis-dashboard-orchestrator` | 7-agent 빌드 오케스트레이터 (Architect/Backend/Frontend/Asset-Intel/Market-Intel/Security/QA) |
| `kis-integration` | KIS API 클라이언트, 토큰 관리, 다중 계좌, 잔고·거래·배당 동기화, Cron |
| `asset-classification` | ETF 파싱, 자산군/국가/통화/섹터 분류, 채권 분석, 자산배분 엔진 |
| `market-sources` | 마켓 인사이트 소스 큐레이션, 뉴스 수집, AI 요약, 워치리스트 |
| `scaffold` | Next.js 16 + shadcn/ui + Tailwind v4 초기화, 보안 기반 파일 |
| `ui-page` | shadcn/ui 페이지 컴포넌트, Recharts, React Query 훅, 반응형 |
| `integration-qa` | API-Frontend 타입 교차 검증, 경계면 버그, 파일경로-링크, DB 스키마-쿼리 |
| `security-review` | 시크릿 스캔, Supabase RLS 검증, 에러 sanitization, pre-commit, 비공개 레포 안전성 |

### 4.7 기타

- `terry-papers/.claude/skills/paper` (canonical) — 4.1에서 다룸
- `terry-slides/.claude/skills/slide` — 슬라이드 생성

---

## 5. 외부 의존성 맵

Codex에서 같은 스킬을 동작시키려면 아래 도구·서비스 접근이 필요.

| 의존성 | 사용 스킬 | 비고 |
|---|---|---|
| **Anthropic API** (`ANTHROPIC_API_KEY`) | 텍스트/JSON LLM 호출 기본 경로 | Claude 계열 모델을 1순위로 사용. credit/quota 오류는 fallback 없이 사용자에게 보고 |
| **OpenAI API** (`OPENAI_API_KEY`) | `image-gen`, `curate-paper-images`, `insert-chapter-images`, embeddings 등 Anthropic 미지원 기능 | 이미지 생성·임베딩처럼 Anthropic에서 직접 지원하지 않는 기능에 사용. credit/quota 오류는 사용자에게 보고 |
| **Anthropic SDK** | `survey`, `cosmax-esg-orchestrator` 등 멀티에이전트 | TeamCreate/SendMessage 백엔드 |
| **Obsidian CLI** + vault 경로 | `obsidian-cli`, `obsidian-markdown`, `write`, `draft`, `post`, `task` 등 | 사용자 로컬 vault에 강결합 |
| **Cloudflare R2** (`wrangler r2 object put`) | `post`, `paper`, `del`, `infra-optimize` | 이미지·PDF 저장 |
| **Cloudflare Pages** (`wrangler deploy`) | `survey --deploy`, `deploy-cloudflare`, `post`/`paper` 재배포 | 정적 사이트 |
| **Cloudflare Workers** | `post`, `paper`, `del` | API 백엔드 |
| **Supabase** | `post`/`paper`/`survey`/`project` (visibility=private/group), `security-review` | 비공개 콘텐츠 + RLS |
| **Substack API** | `share`, `send-digest` | 뉴스레터 발행 |
| **Facebook/Threads/LinkedIn/X/Bluesky API** | `share` | 소셜 발행 |
| **arXiv / Semantic Scholar** | `paper`, `paper-search`, `literature-research`, `deep-literature-research` | 학술 검색 |
| **GraphRAG-lite** (자체 구현) | `paper-search` | 임베딩 + BFS + alignment |
| **`gh` CLI** | `security-audit`, PR 관련 작업 | GitHub |
| **`gitleaks`**, **`osv-scanner`** | `security-audit` | 선택적, 없으면 grep fallback |
| **`defuddle` npm CLI** | `defuddle` | 웹페이지 클러터 제거 |
| **`md-to-pdf`** + **PyMuPDF** | `pdf-update` | PDF 빌드 |
| **KIS Open API** | `kis-integration`, `market-sources` | 한국투자증권 |
| **구글 캘린더 API** | `cal` | terry.t.um 개인 캘린더 |

---

## 6. 포팅 평가 표 (객관 정보 only — 우선순위는 사용자가 결정)

각 도메인별로 Codex 포팅 시 고려할 차원을 정리. **추천 순서는 의도적으로 비워둠.**

차원 설명:
- **Codex 강점 활용도**: long context / code-heavy generation / tool use / 단일 에이전트 깊이 — Codex가 잘하는 영역
- **외부 의존성 무게**: 외부 API 키·CLI·로컬 환경에 얼마나 강결합되어 있는지 (높을수록 그대로 포팅 어려움)
- **멀티에이전트 필요도**: TeamCreate 류 런타임 없으면 재설계 필요한 정도
- **활용도**: 사용자가 실제로 자주 쓰는가 (호출 빈도 또는 description-trigger 자연어 발동 빈도)

| 도메인 / 스킬군 | Codex 강점 활용도 | 외부 의존성 무게 | 멀티에이전트 필요도 | 활용도 |
|---|---|---|---|---|
| `harness` (메타 스킬) | 상 (코드·템플릿 생성) | 하 | 하 | 중 |
| `whytree` (목적 발견) | 중 (대화형) | 하 (`~/.whytree/` 로컬) | 하 | 하 (0회) |
| `image-gen` | 하 (이미지 API 래퍼) | 상 (OpenAI Images) | 하 | **상** (sub-call 다수) |
| `pdf-update` | 하 (스크립트 호출) | 중 (`md-to-pdf`, PyMuPDF) | 하 | 중 |
| `cite-post` | 중 (인용 매칭) | 중 (terry-surveys 인덱스) | 하 | 하 (0회) |
| `code-audit` / `security-audit` / `wip-audit` | 중 (보안·위생 점검) | 중 (`gitleaks`, `osv-scanner`, `gh`) | 하 (라우터) | 하 (0회) |
| 콘텐츠 파이프라인 (`write`, `post`, `paper`, `draft`, `share`, `del`) | **상** (긴 텍스트 생성·편집) | **상** (Obsidian, R2, Cloudflare, Supabase, 소셜 API) | 중 (일부 multi-agent) | **상** (description-trigger 다수) |
| `paper-search` | 중 (검색·랭킹) | 중 (arXiv/SS, 자체 그래프) | 하 | 하 |
| `survey` (서베이 책) | 중 (긴 문서) | **상** (Cloudflare + 7 에이전트 + arXiv) | **상** (7-agent 자율 병렬) | 중 |
| `book-write` (terry-facebook-pull) | 상 (긴 글) | 중 | 상 (drafter + 3 readers + critic + editor + reviser) | 중 |
| `cosmax-esg-*` (ESG 전략서) | 상 (한국어 5K-7K자/챕터) | 중 (1차 자료 로컬 파일) | 상 (4-agent) | 중 |
| `physical-ai-news` (뉴스 큐레이션) | 중 | 상 (크롤러 + Cloudflare + Substack) | 상 (4-agent) | - |
| `kis-dashboard-orchestrator` (투자 대시보드) | 상 (Next.js + 보안) | 상 (KIS API) | 상 (7-agent) | - |
| `obsidian-*` (vault 조작) | 중 | **상** (Obsidian 강결합, macOS 경로) | 하 | 상 |
| `tagging` / `task` / `cal` / `create` | 하 (단순 CRUD) | 중-상 | 하 | 중 |
| `defuddle` | 하 (CLI 래퍼) | 하 (`defuddle` npm) | 하 | 중 |
| `infra-optimize` | 상 (리팩토링) | 상 (R2, Git) | 중 (Architect→Engineer→QA) | 하 |

읽는 법: **Codex 강점 활용도 ≥ 중 + 외부 의존성 ≤ 중 + 멀티에이전트 ≤ 중** 인 항목이 그대로 옮기기 쉬운 후보. 외부 의존성이 큰 항목은 Codex 측 환경에서 같은 API 키·CLI 가 잡혀 있는지 먼저 확인.

---

## 7. archived 스킬 목록

**이번 정리 결과: 0개**

사용자 정리 기준이 보수적이었음 (글로벌은 중복/대체된 것만, 프로젝트는 0회 호출 + 미문서화 둘 다 충족, 내장 슬래시 커맨드는 손대지 않음). 글로벌 8개 중 중복/대체된 사례는 없음 — `gemini-3-image-generation` → `image-gen` 리네임은 이미 과거에 정리됨. 프로젝트 스킬 59개 중 일부는 호출 카운트 0이지만 모두 SKILL.md description이 충실하고 다른 스킬·CLAUDE.md·README에서 참조되고 있어 "미문서화" 조건 미충족.

향후 정리가 필요하면 다음 후보를 우선 검토 가능 (이번엔 archive 안 함):
- `terry-surveys/survey-lite` — `/survey` 자체가 `--orchestrate` 기본화하면서 토큰 절약 분기의 존재 의의가 모호해짐
- `terry-surveys/research-book-orchestrator`, `tactile-book-orchestrator` — `/survey --orchestrate` 통합 패턴이 정착하면 책별 orchestrator가 dead가 될 가능성
- `whytree` (글로벌) — 30일 0회, 글로벌 단독 기능이지만 활용 빈도 낮음

---

## 8. 포팅 시 함정 (Gotchas)

1. **Symlink 의존성**: macOS의 절대경로 symlink로 운영되는 스킬 (`~/.claude/skills/cite-post` 등)은 Codex가 다른 환경에서 돌릴 때 깨진다. 빌드 시 동기화 스크립트로 대체하거나 canonical 경로를 명시적 import로 변경.

2. **Description-trigger 의존**: 사용자는 "글 써줘", "태그 달아줘" 같은 자연어로 스킬을 발동한다. Codex의 슬래시 명령만 지원하는 모드에서는 이런 트리거가 동작하지 않아 사용성이 크게 떨어진다. Codex에 자연어→스킬 라우터를 만들거나, 사용자에게 명시적 호출을 요구하는 두 방향 중 선택 필요.

3. **TeamCreate 멀티에이전트 부재**: `survey --orchestrate`, `cosmax-esg-orchestrator`, `book-write`, `kis-dashboard-orchestrator`, `build-radar` 등의 핵심 워크플로우는 Claude Code 의 `TeamCreate + SendMessage + TaskCreate` 에 강결합. Codex에 동등한 런타임이 없으면 단일 에이전트 + sequential phase 방식으로 다운그레이드 재설계 필요.

4. **Provider 우선순위 정책**: Codex와 Claude에서는 BizRouter를 사용하지 않는다. 텍스트/JSON LLM 호출은 Anthropic을 1순위로 쓰고, 이미지 생성·임베딩처럼 Anthropic 미지원 기능은 OpenAI를 사용한다. credit/quota 오류는 조용히 fallback하지 말고 사용자에게 보고한다.

5. **canonical source 패턴**: 같은 스킬을 한 곳에 정의하고 여러 프로젝트가 참조. Codex에서 같은 스킬을 복붙 N번 깔면 갱신 시 sync 문제가 그대로 재발한다. 패키지 단위 / git submodule / 빌드타임 동기화 셋 중 하나로 결정 필요.

6. **Obsidian / Cloudflare 경로 강결합**: vault 경로, `wrangler` 인증, R2 버킷명, Pages 프로젝트명 등이 사용자 로컬 환경에 박혀 있음. Codex 측 컨테이너/원격 환경에서는 모두 환경변수 또는 config 파일로 빠져나와야 함.

7. **harness-100 템플릿 (630개) 처리**: 100 시나리오 × 평균 6.3 스킬의 벤치마크 fixture. Codex 측에서 같은 벤치마크를 운영할 게 아니면 포팅 대상에서 명시적으로 제외.

8. **`SKILL.md` vs `skill.md` 혼재**: 일부 오래된 스킬이 소문자 `skill.md` 사용. Codex 측 파서가 어느 한쪽만 인식하면 일부 스킬이 누락된다.

9. **사용자 글로벌 CLAUDE.md 규칙**: 빌드/배포 동시 실행 금지, ENOENT 발생 시 `pgrep`로 orphan 정리, 멀티라인 명령어는 스크립트로 묶기 — 등의 규칙이 사용자 글로벌 `~/.claude/CLAUDE.md`에 있음. Codex 측 시스템 프롬프트에도 동일 규칙이 들어가야 같은 사용자 경험.

10. **`fast` 모드 / 모델 라우팅**: Claude Code는 `/fast`로 Opus 4.6 vs Opus 4.7 토글. Codex 측은 모델 변경 메커니즘이 다르므로 사용자에게 동등 토글을 어떻게 제공할지 별도 설계.

---

## 9. 참조

- 글로벌 스킬: `/Users/terrytaewoongum/.claude/skills/`
- 플러그인: `/Users/terrytaewoongum/.claude/plugins/cache/`
- 프로젝트 스킬: `/Users/terrytaewoongum/Codes/*/.claude/skills/`
- canonical sources: `terry-code-management/skills/`, `terry-surveys/.claude/skills/`, `terryum-ai/.claude/skills/`, `terry-obsidian/.claude/skills/`, `terry-papers/.claude/skills/`
- 사용자 글로벌 룰: `/Users/terrytaewoongum/.claude/CLAUDE.md`
- 사용자 메모리: `/Users/terrytaewoongum/.claude/projects/-Users-terrytaewoongum-Codes/memory/MEMORY.md`
- 본 인벤토리 작성 시 사용한 플랜: `/Users/terrytaewoongum/.claude/plans/mossy-spinning-bonbon.md`
