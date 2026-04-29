#!/bin/bash
# Scan every git repo under $CODES_ROOT (default: ~/Codes).
# Auto-discovers group folders (any top-level directory that contains git repos).
# Outputs TSV: PROJECT  GROUP  LAST_COMMIT  CURRENT_BRANCH  UNCOMMITTED  FEATURE_BRANCHES  STASH

set -e
CODES="${CODES_ROOT:-$HOME/Codes}"

# Discover top-level group folders unless CODES_GROUPS is explicitly set
if [ -n "$CODES_GROUPS" ]; then
  GROUPS="$CODES_GROUPS"
else
  GROUPS=$(find "$CODES" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -exec basename {} \; | sort)
fi

printf 'PROJECT\tGROUP\tLAST_COMMIT\tCURRENT_BRANCH\tUNCOMMITTED\tFEATURE_BRANCHES\tSTASH\n'

for group in $GROUPS; do
  group_dir="$CODES/$group"
  [ -d "$group_dir" ] || continue
  for dir in "$group_dir"/*/; do
    [ -d "${dir}.git" ] || continue
    name=$(basename "$dir")
    last=$(git -C "$dir" log -1 --format=%cs 2>/dev/null || echo "")
    branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "")
    uncommitted=$(git -C "$dir" status --short 2>/dev/null | wc -l | tr -d ' ')
    feat=$(git -C "$dir" branch --list 2>/dev/null | grep -v -E '^[* ] +(main|master)$' | wc -l | tr -d ' ')
    stash=$(git -C "$dir" stash list 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$group" "$last" "$branch" "$uncommitted" "$feat" "$stash"
  done
done | sort -t$'\t' -k3,3r
