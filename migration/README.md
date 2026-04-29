# Laptop Migration / 노트북 이전

A 5-step pipeline to move every codebase under `~/Codes/` to a new laptop without losing any working-tree files, symlinks, or session state.

`~/Codes/` 하위 모든 코드베이스를 새 노트북으로 옮기는 5단계 파이프라인. 작업 파일·심링크·세션 상태 모두 보존.

---

## What gets transferred / 이전되는 것

| Type / 종류 | How / 방식 |
|---|---|
| Public Git repos / 공개 Git 레포 | Cloned via `gh repo list <user> --visibility public` |
| Private Git repos / 비공개 Git 레포 | Cloned via `--visibility private` (auth required) |
| Working-tree files NOT in any repo / 어느 레포에도 없는 작업 파일 | Encrypted bundle via USB/cloud |
| Symlinks (e.g. `<repo-A>` → `<repo-B>`) / 심링크 | Manifest captured + restored on target |
| `~/.claude/` configs, plans, dev-logs / 설정·플랜·로그 | Bundled |
| `.env`, secrets / 시크릿 | **NOT bundled** — manually re-create on target / 자동 이전 안 됨, 수동 재발급 |

---

## 5 steps / 5단계

### On the OLD laptop / 기존 노트북에서

```bash
cd ~/Codes/terry-code-management/migration
./1-bundle-from-source.sh                    # creates output/bundle-YYYYMMDD.tar.gz.gpg
```

This produces `output/bundle-<date>.tar.gz.gpg` (GPG-symmetric encrypted, password prompted).

이 단계는 `output/bundle-<date>.tar.gz.gpg` 를 생성합니다 (GPG 대칭 암호화, 비밀번호 입력).

Copy the file to USB / cloud / scp.

USB / 클라우드 / scp 로 복사하세요.

### On the NEW laptop / 새 노트북에서

```bash
# 1. Install gh CLI and authenticate (both accounts if needed)
gh auth login                                # interactive
# gh auth login -h github.com (repeat if 2 accounts)

# 2. Clone this repo first (everything else depends on its scripts)
git clone https://github.com/terryum/terry-code-management.git ~/Codes/terry-code-management
cd ~/Codes/terry-code-management/migration

# 3. Clone all public + private GitHub repos
./2-clone-public-repos.sh    [GH_USER] [GH_USER2 ...]
./3-clone-private-repos.sh   [GH_USER] [GH_USER2 ...]

# 4. Place your bundle file in migration/input/, then:
./4-restore-bundle.sh        ./input/bundle-<date>.tar.gz.gpg

# 5. Verify everything is in place
./5-verify-migration.sh
```

---

## What `5-verify-migration.sh` checks / 검증 항목

- ✅ Every repo from the source manifest exists on target / 모든 소스 레포가 타깃에 있는가
- ✅ Each repo's HEAD commit matches the source manifest / HEAD commit 일치 여부
- ✅ Symlinks are re-created and resolve / 심링크 재생성 + 정상 해석
- ✅ `~/.claude/skills/` symlinks point to this repo / 스킬 심링크 정상
- ✅ `~/.claude/plans/`, `~/Codes/.dev-log/` files restored / 플랜·로그 복원 확인
- ⚠ Secrets reminder — list of `.env*` files that need manual recreation / 수동 재발급 필요 시크릿 안내

Output is a green/yellow/red summary. Anything red blocks day-1 work.

녹/황/적 요약 출력. 적색이 있으면 day-1 작업 시작 금지.

---

## Bundle contents / 번들 내용물

`bundle-<date>.tar.gz.gpg` 안에는:

```
manifest.json                    각 repo 의 origin URL + HEAD commit + symlinks 메타정보
non-git/<rel-path>...            어떤 git repo 에도 속하지 않은 작업 파일
home-claude/                     ~/.claude/ 사본 (settings.local.json 제외)
home-claude-plans/               ~/.claude/plans/ 사본
codes-dev-log/                   ~/Codes/.dev-log/ 사본
symlinks.txt                     심링크 매핑 (target → source)
```

---

## Security / 보안

- Bundle 은 GPG `--symmetric` (AES-256) 암호화. 비밀번호는 사용자가 USB/cloud 로 보내지 말고 별도 채널로 전달.
- `.env`, `.env.local`, `*.key`, `*.pem` 류는 번들에 포함하지 않음 — `1-bundle-from-source.sh` 가 명시적으로 제외.
- `manifest.json` 은 타깃 검증용이며 비공개 레포 이름이 들어가지만, 이 파일은 번들 안에 있고 번들은 암호화되어 있으므로 OK.
- 검증 끝나면 번들 파일은 즉시 삭제 권장 (`shred -uvz bundle-*.tar.gz.gpg`).

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|---|---|---|
| `gh repo list` 가 비어 있음 | 인증 안 됨 또는 다른 계정 | `gh auth status`, `gh auth switch --user <name>` |
| 심링크 복원 실패 | 타깃 파일이 아직 없음 | 다른 repo clone 완료 후 `4-restore-bundle.sh` 다시 실행 |
| `.env` 미재발급 | 의도된 동작 | 각 repo 의 `.env.example` 참고하여 직접 작성 |
| GPG 복호화 실패 | 비밀번호 오류 | 다시 시도 (3회 후 cooldown 있음) |
