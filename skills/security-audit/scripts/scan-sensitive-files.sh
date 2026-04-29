#!/bin/bash
# Detect sensitive files actually tracked in git.
# Output: TSV — REPO  PATTERN  PATH

set -e
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
DISCOVER="$SCRIPT_DIR/discover-repos.sh"

printf 'REPO\tPATTERN\tPATH\n'

# Patterns: PATTERN_NAME|REGEX
PATTERNS='
env-file|^(\.|.*/)?\.env(\..*)?$
private-key|.*\.(key|pem|p12|pfx)$
ssh-key|.*/(id_rsa|id_ed25519|id_ecdsa|id_dsa)(\.pub)?$
credentials|(credentials|secrets|service-account)\.json$
sqlite-db|.*\.(sqlite|sqlite3|db)$
node-modules|.*node_modules/.+
pycache|.*__pycache__/.+
ds-store|.*\.DS_Store$
'

bash "$DISCOVER" | while read -r repo; do
  name=$(basename "$repo")
  files=$(git -C "$repo" ls-files 2>/dev/null) || continue
  while IFS='|' read -r pname regex; do
    [ -z "$pname" ] && continue
    echo "$files" | grep -E "$regex" | while read -r f; do
      printf '%s\t%s\t%s\n' "$name" "$pname" "$f"
    done
  done <<< "$PATTERNS"
done
