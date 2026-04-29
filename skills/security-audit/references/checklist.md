# Security Audit Checklist — 검사 패턴 단일 근거

## 1. Secret patterns (high-confidence regex)

| 종류 | regex | severity |
|---|---|---|
| AWS access key | `AKIA[0-9A-Z]{16}` | HIGH |
| AWS secret key | `aws_secret_access_key.{0,20}["']?[A-Za-z0-9/+=]{40}` | HIGH |
| OpenAI API key | `sk-[A-Za-z0-9]{20,}` | HIGH |
| Anthropic API key | `sk-ant-[A-Za-z0-9_-]{20,}` | HIGH |
| GitHub PAT | `gh[pousr]_[A-Za-z0-9]{36,}` | HIGH |
| Slack bot token | `xox[abp]-[A-Za-z0-9-]{20,}` | HIGH |
| GCP service account | `"type":\s*"service_account"` | HIGH |
| RSA private block | `-----BEGIN (RSA \|OPENSSH \|EC \|DSA )?PRIVATE KEY-----` | HIGH |
| JWT (3 parts) | `eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` | MEDIUM |
| Generic password | `password\s*[:=]\s*["'][^"'\s]{8,}` | MEDIUM |

추가 패턴은 `gitleaks` 의 [default rules](https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml) 참조.

## 2. Sensitive file patterns

절대 git tracked 되면 안 되는 파일:

```
.env, .env.*               환경변수 (시크릿 포함 가능)
*.key, *.pem, *.p12        암호화 키 / 인증서
id_rsa*, id_ed25519*       SSH private key
credentials.json           GCP service account / 일반 자격증명
secrets.json               자격증명
*.sqlite, *.db (>1MB)      로컬 DB 덤프
.DS_Store                  macOS 메타 (사소하지만 정보 누설)
node_modules/, __pycache__/ 캐시 (gitignore 누락)
```

## 3. Public exposure rules

### Public repo 에 있으면 즉시 경고:
- `.env` 또는 `.env.*`
- 어떤 종류든 private key
- 다른 비공개 레포의 이름이 코드/문서에 등장
- 클라이언트 / 회사명을 식별 가능한 hardcoded 문자열

### Public repo 자체 검토 사항:
- README 가 비공개 시스템의 URL 을 공개하는가
- 의존성 list 가 비공개 패키지 registry 를 노출하는가
- CI 설정 (.github/workflows/*) 이 secrets 변수를 사용하는데 그 변수명이 정보를 누설하는가

## 4. False positive guard

- 다음 패턴은 무시 가능 (dummy / placeholder):
  - `sk-test-...`, `sk-fake-...`, `sk-example-...`
  - `password=password`, `password=changeme`, `password=hunter2`
  - 모든 hex/base64 가 가짜처럼 짧거나(<32 chars) 명백히 lorem ipsum 류
- 단, working tree 에서 dummy 라도 고치는 게 좋음 (사용자가 헷갈림)

## 5. 응급 조치 명령 모음 (출력 전용 — 직접 실행 X)

### Secret 이 git history 에 있을 때:
```bash
# Option A: BFG Repo-Cleaner (추천 — 빠름)
bfg --delete-files <FILE> .git
bfg --replace-text <PATTERNS_FILE> .git
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# Option B: git filter-repo
git filter-repo --path <FILE> --invert-paths
```

### 그 후:
- 노출된 키는 즉시 revoke + 재발급
- public repo 였다면 force-push 후에도 GitHub cache 가 일정 기간 보존됨 → key revocation 이 진짜 fix

### Sensitive file 이 tracking 만 되고 있을 때:
```bash
echo "<PATH>" >> .gitignore
git rm --cached <PATH>
git commit -m "chore: stop tracking <PATH>"
```
