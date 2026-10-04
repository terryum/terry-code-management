#!/bin/bash
# Scan every git repo under $CODES_ROOT (default: ~/Codes).
# Auto-discovers group folders (any top-level directory that contains git repos).
# Outputs TSV: PROJECT  GROUP  LAST_COMMIT  CURRENT_BRANCH  UNCOMMITTED  FEATURE_BRANCHES  STASH

set -e
CODES="${CODES_ROOT:-$HOME/Codes}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
printf 'PROJECT\tGROUP\tLAST_COMMIT\tCURRENT_BRANCH\tUNCOMMITTED\tFEATURE_BRANCHES\tSTASH\n'

while IFS= read -r dir; do
    rel="${dir#$CODES/}"
    group="${rel%%/*}"
    if [ -n "${CODES_GROUPS:-}" ]; then
      case " $CODES_GROUPS " in *" $group "*) ;; *) continue ;; esac
    fi
    origin=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
    name="${origin##*/}"
    name="${name%.git}"
    [ -n "$name" ] || name=$(basename "$dir")
    last=$(git -C "$dir" log -1 --format=%cs 2>/dev/null || echo "")
    branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "")
    uncommitted=$(git -C "$dir" status --short 2>/dev/null | wc -l | tr -d ' ')
    feat=$(git -C "$dir" branch --list 2>/dev/null | grep -v -E '^[* ] +(main|master)$' | wc -l | tr -d ' ')
    stash=$(git -C "$dir" stash list 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$group" "$last" "$branch" "$uncommitted" "$feat" "$stash"
done < <(bash "$SCRIPT_DIR/../../../scripts/discover-repos.sh") | sort -t$'\t' -k3,3r
