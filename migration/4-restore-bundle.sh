#!/bin/bash
# 4-restore-bundle.sh <bundle.tar.gz.gpg>
# Decrypt + extract bundle on the NEW laptop. Restores:
#   - non-git working-tree files into $CODES_ROOT
#   - ~/.claude/, plans, dev-log
#   - symlinks (re-created based on manifest.symlinks)

set -euo pipefail

BUNDLE="${1:-}"
if [ -z "$BUNDLE" ] || [ ! -f "$BUNDLE" ]; then
  echo "Usage: $0 <bundle-YYYYMMDD.tar.gz.gpg>" >&2
  exit 1
fi

CODES="${CODES_ROOT:-$HOME/Codes}"
WORK=$(mktemp -d -t restore-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

echo "[1/4] Decrypting bundle (you will be prompted for the passphrase)..."
gpg --decrypt --output "$WORK/bundle.tar.gz" "$BUNDLE"

echo "[2/4] Extracting..."
mkdir -p "$WORK/extracted"
tar -xzf "$WORK/bundle.tar.gz" -C "$WORK/extracted"

echo "[3/4] Restoring files..."
mkdir -p "$CODES"

# Non-git working-tree files (overwrites OK — these are user data)
if [ -d "$WORK/extracted/non-git" ]; then
  rsync -a "$WORK/extracted/non-git/" "$CODES/"
  echo "  ✓ non-git files → $CODES"
fi

# ~/.claude/ — merge (don't overwrite settings.local.json if user already created it)
if [ -d "$WORK/extracted/home-claude" ]; then
  rsync -a --ignore-existing --exclude='settings.local.json' \
    "$WORK/extracted/home-claude/" "$HOME/.claude/"
  # for plans/skills, we want to overwrite (latest source wins)
  if [ -d "$WORK/extracted/home-claude-plans" ]; then
    mkdir -p "$HOME/.claude/plans"
    rsync -a "$WORK/extracted/home-claude-plans/" "$HOME/.claude/plans/"
  fi
  echo "  ✓ ~/.claude/ + plans → $HOME/.claude/"
fi

# .dev-log
if [ -d "$WORK/extracted/codes-dev-log" ]; then
  mkdir -p "$CODES/.dev-log"
  rsync -a "$WORK/extracted/codes-dev-log/" "$CODES/.dev-log/"
  echo "  ✓ dev-log → $CODES/.dev-log/"
fi

echo "[4/4] Re-creating symlinks from manifest..."
python3 - "$WORK/extracted/manifest.json" "$CODES" <<'PY'
import json, os, sys
manifest_file, codes = sys.argv[1], sys.argv[2]
with open(manifest_file) as f:
    m = json.load(f)
restored = 0
skipped = 0
for sl in m.get("symlinks", []):
    full = os.path.join(codes, sl["path"])
    target = sl["target"]
    parent = os.path.dirname(full)
    if not os.path.exists(parent):
        skipped += 1
        continue
    if os.path.islink(full) or os.path.exists(full):
        skipped += 1
        continue
    try:
        os.symlink(target, full)
        restored += 1
    except OSError as e:
        print(f"  ⚠ symlink failed: {sl['path']} → {target} ({e})")
        skipped += 1
print(f"  ✓ symlinks restored: {restored} (skipped: {skipped})")
PY

echo ""
echo "✓ Bundle restored. Next: ./5-verify-migration.sh"
echo "  Reminder: secrets (.env*, *.key) were NOT in the bundle. Re-create them manually:"
find "$CODES" -name '.env.example' -not -path '*/node_modules/*' 2>/dev/null | head -10 | sed 's/^/    /'
