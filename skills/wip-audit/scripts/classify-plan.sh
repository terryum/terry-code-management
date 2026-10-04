#!/bin/bash
# Identify which project a plan file is most likely about.
# Project list is auto-discovered from $CODES_ROOT (default ~/Codes) — no hardcoded names.
# Heuristic: filename hint first, then keyword frequency in the first 30 lines.
# Outputs the project slug + source ("filename" or "content") on stdout.
# Falls back to "unknown" when no project keyword is hit.
#
# Usage: classify-plan.sh <plan_file>

set -e
PLAN="$1"
[ -f "$PLAN" ] || { echo "unknown"; exit 0; }

CODES="${CODES_ROOT:-$HOME/Codes}"

# Discover all repo names (any directory containing .git/) — sort by length DESC
# so that longer names match before substrings (e.g. "foo-bar" before "foo").
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECTS=$(bash "$SCRIPT_DIR/../../../scripts/discover-repos.sh" \
  | while IFS= read -r repo; do
    origin=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
    name="${origin##*/}"; name="${name%.git}"
    [ -n "$name" ] || name=$(basename "$repo")
    printf '%s\n' "$name"
  done \
  | awk '{ print length, $0 }' | sort -rn | awk '{ print $2 }')

[ -z "$PROJECTS" ] && { echo "unknown"; exit 0; }

FNAME=$(basename "$PLAN")

# 1. Filename hint
for p in $PROJECTS; do
  case "$FNAME" in
    *"$p"*)
      echo "$p (filename)"
      exit 0
      ;;
  esac
done

# 2. Keyword frequency in the first 30 lines
HEAD=$(head -30 "$PLAN" 2>/dev/null)
best_count=0
best_proj="unknown"
for p in $PROJECTS; do
  count=$(echo "$HEAD" | grep -o "$p" | wc -l | tr -d ' ')
  if [ "$count" -gt "$best_count" ]; then
    best_count="$count"
    best_proj="$p"
  fi
done

if [ "$best_count" -eq 0 ]; then
  echo "unknown"
else
  echo "$best_proj (content x$best_count)"
fi
