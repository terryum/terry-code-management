#!/usr/bin/env bash
# Active repositories at any depth, including linked worktrees. Never follow links.
set -euo pipefail
CODES="${CODES_ROOT:-$HOME/Codes}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXCLUDE_FILE="${CODES_EXCLUDE_FILE:-$SCRIPT_DIR/../.local/exclude-paths.txt}"
# Keep the array nonempty for macOS Bash 3.2 with nounset.
EXTRA_PRUNE=(-name .local -o)
if [ -f "$EXCLUDE_FILE" ]; then
  while IFS= read -r rel; do
    case "$rel" in ""|\#*) continue ;; esac
    EXTRA_PRUNE+=(-path "$CODES/$rel" -o)
  done < "$EXCLUDE_FILE"
fi
find "$CODES" \
  \( -type d \( "${EXTRA_PRUNE[@]}" -name .cache -o -name _backups -o -name _archives -o -name .tmp -o -name _workspace -o -name node_modules -o -name vendor -o -name .venv -o -name .pnpm-store -o -name .terraform -o -name .next -o -name .open-next -o -name dist -o -name build -o -name __pycache__ \) -prune \) \
  -o \( -name .git \( -type d -o -type f \) -print -prune \) \
  | while IFS= read -r marker; do dirname "$marker"; done | sort
