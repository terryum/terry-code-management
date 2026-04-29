#!/bin/bash
# Discover every git repo under $CODES_ROOT (default: ~/Codes).
# Output: one absolute path per line.
# Used by all 4 scan scripts as the input list.

CODES="${CODES_ROOT:-$HOME/Codes}"
find "$CODES" -mindepth 2 -maxdepth 4 -type d -name '.git' 2>/dev/null \
  | xargs -I{} dirname {} \
  | grep -v "$CODES/terry-code-management$"  # exclude self
