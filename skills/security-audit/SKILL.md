---
name: security-audit
description: |
  보안 점검 sub-audit — secret leak 스캔(gitleaks), 의도치 않은 public 노출 점검,
  의존성 취약점 (OSV) 스캔, .env 등 민감 파일이 git에 들어갔는지 검사. 일반적으로
  사용자는 `/code-audit` 을 통해 호출 — 직접 호출은 '/security-audit' 또는
  'security-audit 만 실행' 처럼 명시적일 때만. 사용자가 그냥 '보안 점검해줘' 라고
  하면 `/code-audit` 라우터가 이 스킬을 호출함. 단일 파일 코드 리뷰는 이 스킬 대상 아님.
---

# /security-audit — 코드베이스 보안 점검

매번 commit/push 할 때마다 일일이 의식하지 않아도 되도록, 이 스킬이 모든 repo 를
한 번에 훑어서 보안 이슈를 잡아낸다.

## 검사 항목 (4 종)

### 1. Secret leak — git 히스토리에 시크릿이 들어갔는가
- gitleaks 가 설치돼 있으면 `gitleaks detect`, 없으면 grep 패턴 fallback
- 검사 패턴: AWS keys, OpenAI/Anthropic keys, GitHub tokens, generic `sk-*` / `ghp_*` / `xoxb-*`,
  RSA private blocks, JWT, password=...
- 대상: 각 repo 의 working tree + git log (`--all`)
- 산출: repo 별 hit 수 + 가장 최근 hit 의 commit hash + 파일 경로

### 2. Public exposure — public repo 에 들어가면 안 되는 것이 들어갔는가
- `gh repo view <owner>/<name>` 로 visibility 확인
- public repo 에 다음이 있으면 경고:
  - `.env`, `.env.*`, `*.key`, `*.pem`, `credentials.json`, `secrets.json`
  - hardcoded URLs containing private services (검출 대상이 사용자가 정의한 패턴)
  - 다른 비공개 레포의 이름 (사용자 인벤토리 기반)
- 사용자 GitHub 의 모든 public repo 를 순회

### 3. Dependency vulnerabilities (OSV)
- `osv-scanner` 가 설치돼 있으면 각 repo 에서 `osv-scanner --recursive .` 실행
- 없으면 `npm audit` (Node), `pip-audit` (Python), `cargo audit` (Rust) 로 fallback
- HIGH/CRITICAL 만 보고. 사용자가 묻지 않으면 LOW/MEDIUM 은 생략

### 4. Sensitive file presence — 절대 git 에 들어가면 안 되는 파일
- 각 repo 의 git tracking 파일 목록에서 다음 패턴 grep:
  ```
  .env (모든 변형)
  *.key, *.pem, *.p12
  id_rsa*, id_ed25519*
  *.sqlite, *.db (size > 1MB)
  __pycache__, node_modules (.gitignore 누락)
  ```

## Workflow (5 stages)

### Stage 1 — PREFLIGHT
도구 가용성 점검 (모든 도구 설치 안 되어 있어도 진행 — fallback 사용):
```bash
which gitleaks osv-scanner gh
```

### Stage 2 — DISCOVERY
스캔 대상 자동 발견:
- 로컬 repo: `bash scripts/discover-repos.sh` (`$CODES_ROOT` 하위 git repo 모두)
- 원격 public repo: `gh repo list <user> --visibility public --json name,url`
- 사용자 인벤토리: `references/checklist.md` 의 sensitive file 패턴 로드

### Stage 3 — SCAN (병렬)
4가지 검사를 병렬 실행. 각 결과는 임시 JSON 으로 모음:
```bash
bash scripts/scan-secrets.sh > /tmp/secaudit/secrets.json
bash scripts/scan-public-exposure.sh > /tmp/secaudit/exposure.json
bash scripts/scan-dependencies.sh > /tmp/secaudit/deps.json
bash scripts/scan-sensitive-files.sh > /tmp/secaudit/files.json
```

repo 가 30개 이상이면 sub-agent (general-purpose) 에 위임 — main context 보호.

### Stage 4 — REPORT
4 카테고리 표:

```
🔴 CRITICAL — 즉시 조치 필요
  - <repo>: <issue> (<file>:<line> or commit <sha>)

🟠 HIGH — 24시간 내
  - ...

🟡 MEDIUM — 다음 commit 전
  - ...

✅ CLEAN — 모든 검사 통과한 repo 목록 (한 줄 요약)
```

### Stage 5 — REMEDIATION
사용자가 카테고리 선택하면 자동으로:
- secret leak 발견 시: `git filter-repo` 또는 BFG 추천 커맨드 출력 (직접 실행은 안 함 — destructive)
- sensitive file 발견 시: `.gitignore` 추가 + `git rm --cached` 명령 출력
- dependency vuln: `npm audit fix` / `pip install -U <pkg>` 명령 출력
- public exposure: 해당 파일을 다른 private repo 로 이동 권고

대다수의 remediation 은 destructive 또는 user judgment 필요 → 자동 실행 안 함.
명령만 출력하고 사용자가 검토 후 실행.

## 트리거 매칭

✅ 사용 시점:
- "보안 점검", "/security-audit", "시크릿 스캔", "취약점 검사"
- "public repo 에 뭐 빠진 것 없나", "키 노출 확인"
- "gitleaks 돌려줘", "OSV 스캔"

❌ 다른 스킬 사용:
- "이 PR 리뷰해줘" → `/security-review` 또는 `/review`
- "단일 파일 보안 검토" → 직접 코드 리뷰
- "settings.json 권한 줄여줘" → `/update-config`

## 참조 문서

- `references/checklist.md` — 검사 패턴 단일 근거
- `references/false-positive-guide.md` — 흔한 false positive 와 무시 룰
- `scripts/scan-secrets.sh` 등 4개 스캔 스크립트
- `scripts/discover-repos.sh` — 스캔 대상 자동 발견

## 안전 가드

- **자동 실행 절대 안 함** — 모든 remediation 은 명령 출력만, 사용자가 직접 실행
- **민감 정보 노출 금지** — 검출된 secret 자체는 출력하지 않고 패턴 + 위치만 표시
  - 잘못된 예: `OPENAI_API_KEY=sk-abc123...` (전체 출력)
  - 올바른 예: `OpenAI API key 형식 매치, .env:3 (앞 6자: sk-abc***)`
- **GH API rate limit 존중** — public exposure 검사는 repo 100개당 1초 sleep
- **불확실하면 KEEP/WARN** — false positive 의심돼도 일단 표시. 사용자가 ignore 룰 추가
