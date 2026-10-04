#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/../../../scripts/discover-repos.sh" | while IFS= read -r repo; do
  [ "$repo" = "$(cd "$SCRIPT_DIR/../../.." && pwd)" ] || printf '%s\n' "$repo"
done
