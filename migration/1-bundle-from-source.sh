#!/bin/bash
# 1-bundle-from-source.sh
# Run on the OLD laptop. Produces output/bundle-YYYYMMDD.tar.gz.gpg containing:
#   - manifest.json (every repo's origin + HEAD commit + symlink list)
#   - all non-git working-tree files (excluding ignored / sensitive)
#   - ~/.claude/ (without settings.local.json), plans/, dev-log/
# Encrypted with GPG symmetric (AES-256). User is prompted for passphrase.

set -euo pipefail

CODES="${CODES_ROOT:-$HOME/Codes}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/output"
mkdir -p "$OUT"
DATE=$(date +%Y%m%d)
WORK=$(mktemp -d -t bundle-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

echo "[1/6] Building manifest..."
python3 - "$CODES" > "$WORK/manifest.json" <<'PY'
import json, os, subprocess, sys
codes = sys.argv[1]
manifest = {"codes_root": codes, "repos": [], "symlinks": []}
for group in sorted(os.listdir(codes)):
    gpath = os.path.join(codes, group)
    if not os.path.isdir(gpath) or group.startswith('.'):
        continue
    for repo in sorted(os.listdir(gpath)):
        rpath = os.path.join(gpath, repo)
        gdir = os.path.join(rpath, ".git")
        if not (os.path.isdir(gdir) or os.path.isfile(gdir)):
            continue
        try:
            origin = subprocess.check_output(["git", "-C", rpath, "remote", "get-url", "origin"], text=True).strip()
        except Exception:
            origin = ""
        try:
            head = subprocess.check_output(["git", "-C", rpath, "rev-parse", "HEAD"], text=True).strip()
        except Exception:
            head = ""
        manifest["repos"].append({
            "group": group, "name": repo, "path": os.path.relpath(rpath, codes),
            "origin": origin, "head": head,
        })

# Walk for symlinks under codes_root
for root, dirs, files in os.walk(codes, followlinks=False):
    # don't descend into .git or node_modules
    dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "__pycache__", ".next", ".open-next")]
    for entry in dirs + files:
        full = os.path.join(root, entry)
        if os.path.islink(full):
            target = os.readlink(full)
            manifest["symlinks"].append({
                "path": os.path.relpath(full, codes),
                "target": target,
            })
print(json.dumps(manifest, indent=2, ensure_ascii=False))
PY

echo "[2/6] Collecting non-git working-tree files..."
mkdir -p "$WORK/non-git"
# Files at $CODES root (excluding sensitive)
find "$CODES" -maxdepth 1 -type f \
  ! -name '.env*' ! -name '*.key' ! -name '*.pem' ! -name '*.p12' \
  ! -name 'credentials.json' ! -name 'secrets.json' ! -name '.DS_Store' \
  -exec cp -p {} "$WORK/non-git/" \;

# /Codes subfolders that are NOT git repos (e.g. archives, docs)
for sub in "$CODES"/*/; do
  name=$(basename "$sub")
  if [ ! -d "$sub.git" ] && [ ! -d "$sub/.git" ]; then
    # if it's a group folder (contains git repos), skip it (those are handled by manifest)
    has_repos=$(find "$sub" -mindepth 2 -maxdepth 3 -type d -name '.git' -print -quit 2>/dev/null)
    if [ -z "$has_repos" ]; then
      echo "  including non-repo subfolder: $name"
      mkdir -p "$WORK/non-git/$name"
      rsync -a --exclude='.env*' --exclude='*.key' --exclude='*.pem' \
        --exclude='credentials.json' --exclude='secrets.json' \
        --exclude='node_modules' --exclude='__pycache__' --exclude='.DS_Store' \
        "$sub/" "$WORK/non-git/$name/"
    fi
  fi
done

echo "[3/6] Copying ~/.claude/ (sans local settings)..."
mkdir -p "$WORK/home-claude"
rsync -a --exclude='settings.local.json' --exclude='*.local.json' \
  --exclude='*.log' --exclude='shell-snapshots' --exclude='todos' \
  "$HOME/.claude/" "$WORK/home-claude/" 2>/dev/null || true

echo "[4/6] Copying ~/.claude/plans/ and ~/Codes/.dev-log/..."
[ -d "$HOME/.claude/plans" ] && cp -a "$HOME/.claude/plans" "$WORK/home-claude-plans"
[ -d "$CODES/.dev-log" ] && cp -a "$CODES/.dev-log" "$WORK/codes-dev-log"

echo "[5/6] Creating tar archive..."
TAR="$WORK/bundle-$DATE.tar.gz"
tar -czf "$TAR" -C "$WORK" manifest.json non-git home-claude home-claude-plans codes-dev-log 2>/dev/null

echo "[6/6] Encrypting with GPG (you will be prompted for a passphrase)..."
echo "      Use a STRONG passphrase. Send it to yourself via a separate channel — not USB."
gpg --symmetric --cipher-algo AES256 --output "$OUT/bundle-$DATE.tar.gz.gpg" "$TAR"

SIZE=$(du -h "$OUT/bundle-$DATE.tar.gz.gpg" | cut -f1)
echo ""
echo "✓ Bundle created: $OUT/bundle-$DATE.tar.gz.gpg ($SIZE)"
echo "  Sensitive files (.env, *.key, *.pem) were excluded — re-create them on the new laptop."
echo "  Next: copy the .gpg file to USB / cloud, and run 4-restore-bundle.sh on the target."
