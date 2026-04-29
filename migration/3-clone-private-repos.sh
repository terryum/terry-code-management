#!/bin/bash
# 3-clone-private-repos.sh [USERNAME ...]
# Clone PRIVATE repos. Same logic as step 2 but with --visibility=private.
# Requires gh authentication with appropriate scopes.

set -euo pipefail

CODES="${CODES_ROOT:-$HOME/Codes}"
DEFAULT_GROUP="${MIGRATION_GROUP:-personal}"
mkdir -p "$CODES/$DEFAULT_GROUP"

USERS=("$@")
if [ ${#USERS[@]} -eq 0 ]; then
  USERS=("$(gh api user -q .login 2>/dev/null)")
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "✗ gh CLI not installed." >&2
  exit 1
fi

for user in "${USERS[@]}"; do
  [ -z "$user" ] && continue
  echo "→ Listing PRIVATE repos for: $user"
  count=$(gh repo list "$user" --visibility private --limit 1000 --json name,url -q '. | length' 2>/dev/null || echo 0)
  echo "  $count private repos found"
  gh repo list "$user" --visibility private --limit 1000 --json name,url \
    -q '.[] | [.name, .url] | @tsv' | while IFS=$'\t' read -r name httpurl; do
    target="$CODES/$DEFAULT_GROUP/$name"
    if [ -d "$target/.git" ]; then
      echo "  ✓ skip (exists): $name"
      continue
    fi
    echo "  ↓ clone $name"
    git clone "$httpurl" "$target" || echo "    ⚠ failed: $name (auth scope?)"
  done
done

echo ""
echo "✓ Private repos cloning done."
echo "  If any repo failed: re-auth with broader scope: gh auth refresh -s repo,read:org"
