#!/bin/bash
# 2-clone-public-repos.sh [USERNAME ...]
# Clone every PUBLIC GitHub repo for the given users (or current authenticated user)
# into $CODES_ROOT/<group>/<name>/. Group folder defaults to "personal".
#
# Pass multiple usernames if you maintain multiple accounts.
# Existing local repos are skipped (no overwrite).

set -euo pipefail

CODES="${CODES_ROOT:-$HOME/Codes}"
DEFAULT_GROUP="${MIGRATION_GROUP:-personal}"
mkdir -p "$CODES/$DEFAULT_GROUP"

USERS=("$@")
if [ ${#USERS[@]} -eq 0 ]; then
  USERS=("$(gh api user -q .login 2>/dev/null)")
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "✗ gh CLI not installed. Install: https://cli.github.com/" >&2
  exit 1
fi

for user in "${USERS[@]}"; do
  [ -z "$user" ] && continue
  echo "→ Listing public repos for: $user"
  count=$(gh repo list "$user" --visibility public --limit 1000 --json name,sshUrl,url -q '. | length' 2>/dev/null || echo 0)
  echo "  $count public repos found"
  gh repo list "$user" --visibility public --limit 1000 --json name,sshUrl,url \
    -q '.[] | [.name, .sshUrl, .url] | @tsv' | while IFS=$'\t' read -r name sshurl httpurl; do
    target="$CODES/$DEFAULT_GROUP/$name"
    if [ -d "$target/.git" ]; then
      echo "  ✓ skip (exists): $name"
      continue
    fi
    echo "  ↓ clone $name"
    git clone "$httpurl" "$target" || echo "    ⚠ failed: $name"
  done
done

echo ""
echo "✓ Public repos cloning done."
echo "  Group folder used: $DEFAULT_GROUP (override with MIGRATION_GROUP=...)"
echo "  Adjust grouping later by moving folders, or by passing different MIGRATION_GROUP per call."
