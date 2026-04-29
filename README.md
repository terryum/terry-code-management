# terry-code-management

A meta-repository for managing many codebases at once: weekly audits, security checks, and laptop migration tooling. Designed to live alongside other repos in a single root folder (e.g. `~/Codes/`) and oversee them all.

여러 코드베이스를 동시에 관리하기 위한 메타 레포 — 주간 위생 점검, 보안 검사, 노트북 이전 도구를 제공합니다. 다른 모든 레포가 한 폴더(`~/Codes/` 등) 아래에 있다는 가정 하에 그 위에서 작동합니다.

---

## What's inside / 무엇이 들어 있는가

```
terry-code-management/
├── skills/
│   ├── weekly-audit/        Weekly housekeeping: scan repos + plans, dead-plan cleanup, handoff prompts
│   └── security-audit/      Cross-repo secret scan, public-exposure check, OSV vulnerability scan
├── migration/               Laptop migration toolkit (source → bundle → target → verify)
├── docs/                    Architecture and security guidance
└── install.sh               Symlink skills into ~/.claude/skills/
```

```
terry-code-management/
├── skills/
│   ├── weekly-audit/        주간 위생 — 레포·플랜 스캔, dead-plan 청소, 핸드오프 프롬프트
│   └── security-audit/      교차 레포 시크릿 스캔, 공개 노출 점검, OSV 취약점 검사
├── migration/               노트북 이전 도구 (소스 → 번들 → 타깃 → 검증)
├── docs/                    아키텍처 및 보안 가이드
└── install.sh               ~/.claude/skills/ 로 스킬 심링크 설치
```

---

## Quick start / 빠른 시작

```bash
git clone https://github.com/terryum/terry-code-management.git
cd terry-code-management
./install.sh                 # symlink skills into ~/.claude/skills/
```

After install, in any Claude Code session:

설치 후 Claude Code 세션에서:

- `/weekly-audit` or "주간 정리해줘" → weekly housekeeping flow
- `/security-audit` or "보안 점검해줘" → cross-repo security scan

---

## Laptop migration / 노트북 이전

When moving to a new machine, `migration/` provides a 5-step pipeline:

새 노트북으로 이전할 때 `migration/` 의 5단계 파이프라인을 따릅니다:

```
[old laptop]                        [usb / cloud transfer]                 [new laptop]

1. bundle-from-source.sh   →   encrypted tar.gz of non-git files     →
                                                                           2. clone-public-repos.sh
                                                                           3. clone-private-repos.sh
                                                                           4. restore-bundle.sh
                                                                           5. verify-migration.sh
```

What gets transferred / 무엇이 옮겨지는가:

| Type | How |
|---|---|
| Public Git repos / 공개 Git 레포 | Cloned dynamically via `gh repo list` (no hardcoded names) — 동적으로 클론 |
| Private Git repos / 비공개 Git 레포 | Same, with `--visibility=private` (auth required) — 인증 후 동일 방식 |
| Working-tree files NOT in any repo / 어느 레포에도 없는 작업 파일 | Encrypted bundle via USB/cloud — 암호화 번들 |
| Symlinks / 심링크 | Re-created by `restore-bundle.sh` — 복원 스크립트가 재생성 |
| `.claude/` configs, plans, dev-logs / 플랜·devlog 등 | Bundled — 번들에 포함 |
| Secrets (`.env`) / 시크릿 | NOT bundled — manually re-create on new machine — 자동 이전 안 됨, 수동 재발급 |

Run `migration/README.md` for full step-by-step instructions.

자세한 단계는 `migration/README.md` 참고.

---

## Design principles / 설계 원칙

1. **No hardcoded private references** — Scripts auto-discover repo names via filesystem and `gh` CLI. No private repo, client, or product names are committed to this public repo.
2. **Read-first by default** — All scans default to read-only. Mutating actions (delete, commit, push) require explicit user confirmation.
3. **Encryption for in-transit data** — Migration bundles are GPG-symmetric encrypted before leaving the source machine.
4. **Skills are portable** — Source of truth lives in this repo; `~/.claude/skills/<name>` are symlinks. Migration is just `git clone + ./install.sh`.

1. **하드코딩된 비공개 정보 없음** — 스크립트는 파일시스템과 `gh` CLI 로 레포 이름을 자동 탐색. 비공개 레포·클라이언트·제품명은 이 공개 레포에 절대 commit 안 됨.
2. **기본 read-only** — 모든 스캔은 read-only 기본. 변경 작업(삭제·커밋·푸시)은 명시적 사용자 확인 필요.
3. **전송 데이터 암호화** — 이전 번들은 소스 머신에서 떠나기 전 GPG 대칭 암호화.
4. **스킬은 이식 가능** — Source of truth 가 이 레포에 있고 `~/.claude/skills/<name>` 은 심링크. 이전은 `git clone + ./install.sh` 한 줄로 끝.

---

## Security posture / 보안 정책

This repo is intentionally **lean and generic**. It contains no API keys, no client names, no private repo references. Before each commit, `skills/security-audit/` self-audits this very repo to ensure nothing leaked.

이 레포는 의도적으로 **얇고 generic**. API 키·클라이언트명·비공개 레포 참조 없음. 매 commit 전 `skills/security-audit/` 가 자체 감사하여 leak 여부 확인.

See `docs/security.md` for details / 상세는 `docs/security.md` 참조.

---

## License

MIT
