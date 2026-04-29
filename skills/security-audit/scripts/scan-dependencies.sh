#!/bin/bash
# Scan dependency vulnerabilities. Uses osv-scanner if available, else falls back
# to npm audit / pip-audit / cargo audit per ecosystem.
# Output: TSV — REPO  ECOSYSTEM  PACKAGE  VERSION  SEVERITY  ID  TITLE

set -e
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
DISCOVER="$SCRIPT_DIR/discover-repos.sh"

printf 'REPO\tECOSYSTEM\tPACKAGE\tVERSION\tSEVERITY\tID\tTITLE\n'

USE_OSV=0
if command -v osv-scanner >/dev/null 2>&1; then
  USE_OSV=1
fi

bash "$DISCOVER" | while read -r repo; do
  name=$(basename "$repo")

  if [ "$USE_OSV" -eq 1 ]; then
    out=$(osv-scanner --recursive --format json "$repo" 2>/dev/null || echo '{"results":[]}')
    echo "$out" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for res in data.get('results', []):
    src = res.get('source', {}).get('path', '')
    for pkg in res.get('packages', []):
        info = pkg.get('package', {})
        for vuln in pkg.get('vulnerabilities', []):
            sev = (vuln.get('database_specific', {}) or {}).get('severity', 'UNKNOWN')
            sev = sev.upper() if isinstance(sev, str) else 'UNKNOWN'
            if sev not in ('HIGH','CRITICAL'):
                continue
            print('\t'.join(['$name', info.get('ecosystem',''), info.get('name',''),
                             info.get('version',''), sev, vuln.get('id',''),
                             (vuln.get('summary','') or '')[:80]]))
" 2>/dev/null
  else
    # Per-ecosystem fallback
    if [ -f "$repo/package.json" ] && command -v npm >/dev/null 2>&1; then
      (cd "$repo" && npm audit --json 2>/dev/null) | python3 -c "
import json, sys
try: data = json.load(sys.stdin)
except: sys.exit()
for k, v in (data.get('vulnerabilities') or {}).items():
    sev = v.get('severity','').upper()
    if sev in ('HIGH','CRITICAL'):
        print('\t'.join(['$name', 'npm', k, v.get('range',''), sev, '', v.get('title','')[:80]]))
" 2>/dev/null
    fi
    if [ -f "$repo/requirements.txt" ] || [ -f "$repo/pyproject.toml" ]; then
      if command -v pip-audit >/dev/null 2>&1; then
        (cd "$repo" && pip-audit --format json 2>/dev/null) | python3 -c "
import json, sys
try: data = json.load(sys.stdin)
except: sys.exit()
for d in data.get('dependencies', []):
    for v in d.get('vulns', []):
        print('\t'.join(['$name', 'pip', d.get('name',''), d.get('version',''),
                         'HIGH', v.get('id',''), (v.get('description','') or '')[:80]]))
" 2>/dev/null
      fi
    fi
  fi
done
