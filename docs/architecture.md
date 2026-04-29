# Architecture

## Repo layout

```
terry-code-management/
├── README.md           Bilingual entry point
├── install.sh          Idempotent installer: symlinks skills/* into ~/.claude/skills/
├── .gitignore          Excludes secrets, machine-specific output, runtime caches
├── skills/
│   ├── weekly-audit/   Multi-repo housekeeping
│   └── security-audit/ Multi-repo security scanning
├── migration/          5-step laptop migration pipeline
└── docs/
    ├── architecture.md (this file)
    └── security.md     Public-repo security policy
```

## Where this repo expects to live

```
~/Codes/                              ← root, not a git repo
├── terry-code-management/  ← this repo, public on GitHub
├── <group-1>/<repo>...     ← user's other repos, dynamically discovered
├── <group-2>/<repo>...     ← any directory pattern works
├── .dev-log/                ← (optional) Claude Code session logs
└── .claude/                 ← (optional) Claude Code project state
```

The skills don't hardcode group names or repo names. `scan-projects.sh` uses `find` to discover any subdirectory, and `classify-plan.sh` derives the repo list from filesystem walk.

## How skills resolve at runtime

1. Claude Code loads skill metadata from `~/.claude/skills/<name>/SKILL.md`
2. `~/.claude/skills/<name>` is a symlink → `~/Codes/terry-code-management/skills/<name>/`
3. Skill's bash scripts use `$CODES_ROOT` (default `~/Codes`) for discovery — no path is hardcoded

This means:
- Editing `terry-code-management/skills/<name>/` immediately updates the live skill (symlink resolves at call time)
- `git pull` on this repo deploys updates
- New laptops only need: `git clone terry-code-management && ./install.sh`

## Migration data flow

```
SOURCE LAPTOP                            TARGET LAPTOP
─────────────                            ─────────────
1-bundle-from-source.sh                  
  ├─ scan ~/Codes/* git repos    →
  ├─ build manifest.json (HEADs, symlinks, origin URLs)
  ├─ tar non-repo files          
  ├─ tar ~/.claude, plans, dev-log
  └─ gpg --symmetric (AES-256)
       ↓
   bundle-YYYYMMDD.tar.gz.gpg          USB / cloud
       ↓                                   ↓
                                       2-clone-public-repos.sh  (gh repo list --visibility public)
                                       3-clone-private-repos.sh (--visibility private)
                                       4-restore-bundle.sh      (gpg -d, untar, rsync, re-symlink)
                                       5-verify-migration.sh    (manifest cross-check)
```

The split between "Git repos via gh CLI" and "encrypted bundle for everything else" exists because:
- Git repos live on GitHub already — no need to bundle (saves space, leverages existing CDN)
- Working-tree state (uncommitted edits, dev logs, plans) only exists on the source machine — must be physically transferred
- Secrets (`.env`) are NOT bundled — must be recreated manually for security hygiene

## Skill design — why "report → ask → execute"

Both skills follow the same shape:
1. SCAN (read-only, atomic — finishes in <30s)
2. TRIAGE (categorize findings)
3. REPORT (single screen, 4 categories with severity)
4. EXECUTE (only after AskUserQuestion confirms)
5. HANDOFF (always print, even if user picked "do nothing")

This is deliberate: an automated system that mutates state without confirmation will eventually destroy the wrong thing. The `AskUserQuestion` boundary is the trust gate.

## Adding a new skill

1. `mkdir skills/<name>/{scripts,references}`
2. Write `skills/<name>/SKILL.md` with proper frontmatter (name, description, triggers)
3. Run `./install.sh` to symlink
4. Verify by triggering the skill in a Claude Code session
