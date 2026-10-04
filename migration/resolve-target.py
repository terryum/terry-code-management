#!/usr/bin/env python3
"""Keep clone destinations consistent with an inventory or migration manifest."""
import json
import os
import subprocess
import sys
from pathlib import Path

codes, group, name, origin = sys.argv[1:5]
root = Path(codes).resolve()

def normalize(url):
    return url.rstrip('/').removesuffix('.git').replace('git@github.com:', 'https://github.com/')

def active(path):
    return not any(part in path.parts for part in ('_backups', '_archives', '.local'))

manifest = os.environ.get('MIGRATION_MANIFEST')
if manifest:
    records = json.loads(Path(manifest).read_text()).get('repos', [])
else:
    discovery = Path(__file__).resolve().parent.parent / 'scripts/discover-repos.sh'
    paths = subprocess.check_output(['bash', str(discovery)], env={**os.environ, 'CODES_ROOT': str(root)}, text=True).splitlines()
    records = []
    for path in paths:
        remote = subprocess.run(['git', '-C', path, 'remote', 'get-url', 'origin'], capture_output=True, text=True).stdout.strip()
        records.append({'path': str(Path(path).relative_to(root)), 'origin': remote, 'is_worktree': (Path(path) / '.git').is_file()})

matches = [record for record in records if normalize(record.get('origin', '')) == normalize(origin)
           and active(Path(record['path'])) and not record.get('is_worktree', False)]
if len(matches) > 1:
    raise SystemExit('multiple matching repositories; supply an unambiguous MIGRATION_MANIFEST')
rel = Path(matches[0]['path']) if matches else Path(group) / ('projects' if group == 'personal' else '') / name
path = (root / rel).resolve()
if not active(rel) or not path.is_relative_to(root):
    raise SystemExit('refusing a backup/local or outside-workspace clone destination')
print(path)
