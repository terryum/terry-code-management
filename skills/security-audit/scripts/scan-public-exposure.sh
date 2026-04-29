#!/bin/bash
# For every local repo whose origin is on GitHub, check:
#   1. Is the remote PUBLIC?
#   2. If so, are sensitive files tracked?
# Output: TSV — REPO  VISIBILITY  ISSUE  PATH

set -e
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
DISCOVER="$SCRIPT_DIR/discover-repos.sh"

printf 'REPO\tVISIBILITY\tISSUE\tPATH\n'

# Sensitive file patterns that should never be in a public repo
SENSITIVE='\.env$|\.env\..*|.*\.key$|.*\.pem$|.*\.p12$|credentials\.json$|secrets\.json$|id_rsa.*|id_ed25519.*'

bash "$DISCOVER" | while read -r repo; do
  [ -d "$repo/.git" ] || continue
  name=$(basename "$repo")

  remote=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "")
  case "$remote" in
    *github.com*) ;;
    *) continue ;;  # not a GitHub repo
  esac

  # Extract owner/name from URL
  slug=$(echo "$remote" | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')

  # Try to determine visibility via gh CLI if logged in; otherwise mark UNKNOWN
  vis="UNKNOWN"
  if command -v gh >/dev/null 2>&1; then
    vis=$(gh repo view "$slug" --json visibility -q .visibility 2>/dev/null || echo "UNKNOWN")
  fi

  # Only check sensitive files for repos that are PUBLIC (or UNKNOWN — better safe)
  case "$vis" in
    PUBLIC|public|UNKNOWN)
      git -C "$repo" ls-files | grep -E "$SENSITIVE" | while read -r f; do
        printf '%s\t%s\t%s\t%s\n' "$name" "$vis" "sensitive-file-tracked" "$f"
      done
      ;;
  esac

  # Also flag if visibility is PUBLIC at all (so user can review the list)
  if [ "$vis" = "PUBLIC" ] || [ "$vis" = "public" ]; then
    printf '%s\t%s\t%s\t%s\n' "$name" "$vis" "is-public" "$slug"
  fi
done
