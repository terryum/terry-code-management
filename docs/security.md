# Security policy / 보안 정책

This repo is **public**. Everything in it is visible to the world. Treat every commit as immutable disclosure.

이 레포는 **공개**. 모든 commit 은 영구 공개로 간주.

## What MUST NOT be committed

- ❌ Real API keys, tokens, OAuth secrets, service account JSON
- ❌ Personal data: emails (other than the maintainer's public one), session UUIDs, internal ticket IDs
- ❌ Any private repo name, client name, internal product name, codename
- ❌ Local file paths that reveal system layout (`/Users/<name>/`, `/home/<name>/`) — use `~/` or env vars instead
- ❌ Hardcoded URLs to private services or staging environments
- ❌ Specific list of repos, projects, or organizations the maintainer works on
- ❌ `.env`, `.env.*`, `*.key`, `*.pem`, `credentials.json`, `secrets.json`

## What is OK

- ✅ Generic patterns and example configurations (e.g. `<USERNAME>`, `<REPO>`)
- ✅ Public GitHub usernames the maintainer chooses to advertise
- ✅ Open-source dependency names and version pins
- ✅ Sample data that is clearly synthetic (`example.com`, `sk-test-fake-...`)

## Pre-commit gate

Before every commit to this repo, run:

```bash
./skills/security-audit/scripts/scan-secrets.sh \
  CODES_ROOT=$(pwd) \
  | head -20
```

`./skills/security-audit/scripts/scan-sensitive-files.sh` should produce no output for this repo.

## Threat model

Assumed attacker:
- Reads every commit + history
- Runs automated secret-scanners against the repo
- Cross-references findings with the maintainer's other public profiles (LinkedIn, Twitter, etc.)

Assumed defender posture:
- Only the maintainer commits
- The maintainer reviews diffs before push
- Skills inside this repo include self-audit scripts that the maintainer runs manually

## If a secret leaks

1. **Revoke immediately**. Pushed-and-deleted is still pushed — GitHub keeps cached refs for ~90 days, mirrors keep it forever.
2. Rewrite history with `git filter-repo` (preferred) or `bfg`.
3. Force-push (`git push --force-with-lease`).
4. Open the repo's "Security" tab to confirm GitHub Secret Scanning detected and revoked the secret.

See `skills/security-audit/references/checklist.md` for exact commands.
