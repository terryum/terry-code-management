#!/bin/bash
# install.sh — symlink skills from this repo into ~/.claude/skills/.
# Idempotent: safe to re-run. Replaces existing skill dirs with symlinks
# (after backing them up).

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SKILLS_TARGET="$HOME/.claude/skills"
mkdir -p "$SKILLS_TARGET"

echo "Installing skills from: $REPO/skills/"
echo "Target: $SKILLS_TARGET"
echo ""

for skill_dir in "$REPO"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  link="$SKILLS_TARGET/$name"

  if [ -L "$link" ]; then
    current=$(readlink "$link")
    if [ "$current" = "$skill_dir" ] || [ "$current" = "${skill_dir%/}" ]; then
      echo "  ✓ already linked: $name"
      continue
    fi
    echo "  ↻ updating link: $name (was → $current)"
    rm "$link"
  elif [ -d "$link" ]; then
    backup="$link.backup-$(date +%Y%m%d-%H%M%S)"
    echo "  ↪ backing up existing dir: $name → $backup"
    mv "$link" "$backup"
  fi

  ln -s "${skill_dir%/}" "$link"
  echo "  ✓ linked: $name"
done

# Make all scripts executable
chmod +x "$REPO"/skills/*/scripts/*.sh 2>/dev/null || true
chmod +x "$REPO"/migration/*.sh 2>/dev/null || true

echo ""
echo "✓ Done. Reload your Claude Code session to pick up the new skills."
echo "  Try: /wip-audit  or  /security-audit"
