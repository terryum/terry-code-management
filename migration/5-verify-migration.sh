#!/bin/bash
# 5-verify-migration.sh
# Cross-check the new laptop's state against the manifest.json bundled in step 1.
# Reports green/yellow/red so you know if day-1 work is safe.

set -euo pipefail

CODES="${CODES_ROOT:-$HOME/Codes}"

# Find the most recent manifest under ~/.claude/ or extracted location
MANIFEST="${1:-}"
if [ -z "$MANIFEST" ]; then
  CANDIDATE=$(find "$CODES" -maxdepth 3 -name 'manifest.json' -path '*/migration/*' 2>/dev/null | head -1)
  MANIFEST="${CANDIDATE:-/tmp/restore-*/extracted/manifest.json}"
fi

if [ ! -f "$MANIFEST" ]; then
  echo "✗ manifest.json not found. Re-run 4-restore-bundle.sh first." >&2
  echo "  Or pass it explicitly: $0 <manifest.json>" >&2
  exit 1
fi

echo "Verifying against manifest: $MANIFEST"
echo ""

python3 - "$MANIFEST" "$CODES" <<'PY'
import json, os, subprocess, sys
mfile, codes = sys.argv[1], sys.argv[2]
m = json.load(open(mfile))

green, yellow, red = [], [], []

# 1. Repos
for r in m.get("repos", []):
    rpath = os.path.join(codes, r["path"])
    if not os.path.isdir(os.path.join(rpath, ".git")):
        red.append(f"missing repo: {r['path']} ({r['origin']})")
        continue
    try:
        head = subprocess.check_output(["git", "-C", rpath, "rev-parse", "HEAD"], text=True).strip()
        if r["head"] and head != r["head"]:
            yellow.append(f"HEAD differs: {r['path']} (was {r['head'][:8]} → now {head[:8]})")
        else:
            green.append(f"repo OK: {r['path']}")
    except Exception as e:
        yellow.append(f"can't check HEAD: {r['path']} ({e})")

# 2. Symlinks
for sl in m.get("symlinks", []):
    full = os.path.join(codes, sl["path"])
    if not os.path.islink(full):
        yellow.append(f"missing symlink: {sl['path']} → {sl['target']}")
    elif not os.path.exists(full):
        yellow.append(f"broken symlink: {sl['path']} → {sl['target']}")
    else:
        green.append(f"symlink OK: {sl['path']}")

# 3. Skills (~/.claude/skills/ should have symlinks pointing to terry-code-management)
skill_dir = os.path.expanduser("~/.claude/skills")
expected = ["wip-audit", "security-audit"]
for s in expected:
    p = os.path.join(skill_dir, s)
    if os.path.islink(p):
        green.append(f"skill linked: {s}")
    elif os.path.isdir(p):
        yellow.append(f"skill is a dir, not a symlink: {s} (run install.sh)")
    else:
        red.append(f"skill not installed: {s} (run terry-code-management/install.sh)")

# 4. Plans / dev-log
if os.path.isdir(os.path.expanduser("~/.claude/plans")):
    n = len([f for f in os.listdir(os.path.expanduser("~/.claude/plans")) if f.endswith(".md")])
    green.append(f"plans dir: {n} files")
else:
    yellow.append("~/.claude/plans missing")

if os.path.isdir(os.path.join(codes, ".dev-log")):
    green.append("dev-log dir present")
else:
    yellow.append("~/Codes/.dev-log missing")

# 5. Secrets reminder (we DON'T verify content — just remind)
env_examples = []
for r in m.get("repos", []):
    p = os.path.join(codes, r["path"], ".env.example")
    if os.path.isfile(p):
        env_examples.append(r["path"])

# Output
print(f"✅ GREEN ({len(green)}): all good — sample:")
for line in green[:5]: print(f"   {line}")
if len(green) > 5: print(f"   ... and {len(green)-5} more")
print()
if yellow:
    print(f"⚠  YELLOW ({len(yellow)}): non-blocking — review and fix:")
    for line in yellow: print(f"   {line}")
    print()
if red:
    print(f"🔴 RED ({len(red)}): BLOCKING — fix before day-1 work:")
    for line in red: print(f"   {line}")
    print()
if env_examples:
    print(f"🔑 SECRETS REMINDER: {len(env_examples)} repo(s) have .env.example — re-create the .env:")
    for p in env_examples[:10]: print(f"   {p}")
    if len(env_examples) > 10: print(f"   ... and {len(env_examples)-10} more")

print()
if red:
    sys.exit(1)
elif yellow:
    sys.exit(2)
else:
    print("All clear.")
PY
