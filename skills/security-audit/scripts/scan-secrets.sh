#!/bin/bash
# Scan every repo under $CODES_ROOT for secret leaks.
# Uses gitleaks if available, otherwise falls back to grep patterns.
# Output: TSV — REPO  SEVERITY  PATTERN  FILE  LINE_OR_COMMIT  PREVIEW

set -e
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
DISCOVER="$SCRIPT_DIR/discover-repos.sh"

printf 'REPO\tSEVERITY\tPATTERN\tFILE\tLINE_OR_COMMIT\tPREVIEW\n'

USE_GITLEAKS=0
if command -v gitleaks >/dev/null 2>&1; then
  USE_GITLEAKS=1
fi

# Grep fallback patterns. Each line: SEVERITY|PATTERN_NAME|REGEX
PATTERNS='
HIGH|aws-access-key|AKIA[0-9A-Z]{16}
HIGH|aws-secret-key|aws_secret_access_key.{0,20}["\x27]?[A-Za-z0-9/+=]{40}
HIGH|openai-api-key|sk-[A-Za-z0-9]{20,}
HIGH|anthropic-api-key|sk-ant-[A-Za-z0-9_\-]{20,}
HIGH|github-pat|gh[pousr]_[A-Za-z0-9]{36,}
HIGH|slack-bot-token|xox[abp]-[A-Za-z0-9-]{20,}
HIGH|gcp-service-account|"type":\s*"service_account"
HIGH|rsa-private-key|-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----
MEDIUM|jwt|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}
MEDIUM|generic-password|password\s*[:=]\s*["\x27][^"\x27\s]{8,}
'

bash "$DISCOVER" | while read -r repo; do
  [ -d "$repo/.git" ] || continue
  name=$(basename "$repo")

  if [ "$USE_GITLEAKS" -eq 1 ]; then
    # gitleaks emits JSON on stdout; we tab-separate the fields we care about
    gitleaks detect --source "$repo" --no-banner --no-color --report-format json --report-path /tmp/secaudit-gitleaks.json --redact 2>/dev/null || true
    if [ -s /tmp/secaudit-gitleaks.json ]; then
      python3 -c "
import json, sys
with open('/tmp/secaudit-gitleaks.json') as f:
    findings = json.load(f) or []
for fnd in findings[:20]:
    sev = 'HIGH'
    print('\t'.join(['$name', sev, fnd.get('RuleID',''), fnd.get('File',''), fnd.get('Commit','') or str(fnd.get('StartLine','')), '(redacted)']))
" 2>/dev/null
    fi
  else
    # grep fallback — working tree only (no git log scan)
    while IFS='|' read -r sev pname regex; do
      [ -z "$sev" ] && continue
      hits=$(grep -rEn --include="*" --exclude-dir=.git --exclude-dir=node_modules \
        "$regex" "$repo" 2>/dev/null | head -3)
      if [ -n "$hits" ]; then
        echo "$hits" | while IFS=: read -r file line content; do
          rel=${file#$repo/}
          preview=$(echo "$content" | cut -c1-30 | tr -d '\n\t')
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$sev" "$pname" "$rel" "$line" "$preview..."
        done
      fi
    done <<< "$PATTERNS"
  fi
done
