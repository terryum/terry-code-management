#!/bin/bash
# List every plan file in ~/.claude/plans/ with its mod date, size, and title.
# Outputs TSV: DATE  NAME  SIZE_KB  TITLE
# Sorted oldest-first (so the cleanup candidates surface at the top).

set -e
PLANS="${PLANS_DIR:-$HOME/.claude/plans}"

[ -d "$PLANS" ] || { echo "no plans dir"; exit 0; }

printf 'DATE\tNAME\tSIZE_KB\tTITLE\n'

for f in "$PLANS"/*.md; do
  [ -f "$f" ] || continue
  date=$(stat -f "%Sm" -t "%Y-%m-%d" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -c1-10)
  name=$(basename "$f")
  size_b=$(stat -f "%z" "$f" 2>/dev/null || stat -c "%s" "$f" 2>/dev/null)
  size_kb=$(( size_b / 1024 ))
  title=$(head -1 "$f" | sed 's/^# *//' | tr -d '\r' | tr '\t' ' ' | cut -c1-90)
  printf '%s\t%s\t%s\t%s\n' "$date" "$name" "$size_kb" "$title"
done | sort
