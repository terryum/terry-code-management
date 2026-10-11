#!/usr/bin/env python3
"""Check repository/navigation inventory; optionally refresh README and install local hooks."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import difflib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

START = '<!-- workspace-inventory:start -->'
END = '<!-- workspace-inventory:end -->'
HOOK_MARKER = '# workspace-readme-managed-hook-v1'


def run(args, cwd):
    # Git exports repository-scoped variables to hooks; inventory must inspect each repo independently.
    env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
    result = subprocess.run(args, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                            capture_output=True, text=True, timeout=45)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed ({result.returncode}); check authentication/network/configuration')
    return result.stdout.strip()


def remote_slug(remote):
    match = re.fullmatch(r'(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+?)(?:\.git)?/?', remote)
    return match.group(1) if match else None


def folders(root):
    """Navigation directories only: project internals are described in their own README."""
    rows = []
    def visit(directory):
        for item in sorted(directory.iterdir()):
            if item.name.startswith('.') or item.name in {'node_modules', '_backups', '_archives', 'build', 'dist'}:
                continue
            rel = item.relative_to(root).as_posix()
            if item.is_symlink():
                rows.append((rel, 'link', os.readlink(item)))
            elif item.is_dir():
                if (item / '.git').exists():
                    rows.append((rel, 'repo', ''))
                else:
                    rows.append((rel, 'local', ''))
                    visit(item)
    visit(root)
    return rows


def metadata(root, repos):
    remotes = {}
    for rel in repos:
        names = run(['git', 'remote'], root / rel).splitlines()
        remotes[rel] = run(['git', 'remote', 'get-url', 'origin'], root / rel) if 'origin' in names else ''
    slugs = sorted({slug for remote in remotes.values() if (slug := remote_slug(remote))})
    def fetch(slug):
        info = json.loads(run(['gh', 'api', f'repos/{slug}'], root))
        return slug, info
    with ThreadPoolExecutor(max_workers=4) as pool:
        info = dict(pool.map(fetch, slugs))
    return remotes, info


def cell(value):
    return (value or '').replace('|', '\\|').replace('\n', ' ').replace('\r', ' ')


def inventory(root):
    rows = folders(root)
    repos = [rel for rel, kind, _ in rows if kind == 'repo']
    remotes, info = metadata(root, repos)
    public = sum(info[remote_slug(remotes[r])]['visibility'] == 'public' for r in repos if remote_slug(remotes[r]))
    private = sum(info[remote_slug(remotes[r])]['visibility'] == 'private' for r in repos if remote_slug(remotes[r]))
    lines = [START, '## 폴더와 저장소 현황', '',
             f'독립 Git 저장소 **{len(repos)}개** · GitHub 공개 **{public}개** · GitHub 비공개 **{private}개**.', '',
             '분류 폴더와 심볼릭 링크에는 독립 저장소가 없습니다. 각 저장소 안의 일반 소스·문서 폴더는 해당 저장소 README에서 설명합니다.', '',
             '| 로컬 경로 | 종류 / 공개 여부 | GitHub 저장소 또는 연결 대상 | GitHub 설명 / 폴더 용도 |',
             '| --- | --- | --- | --- |',
             '| `./` | 로컬 분류 폴더 · 독립 저장소 없음 | — | 개인 작업공간 루트 |']
    for rel, kind, target in rows:
        path = f'[{rel}/]({rel}/)'
        if kind == 'local':
            values = (path, '로컬 분류 폴더 · 독립 저장소 없음', '—', '하위 프로젝트를 묶는 탐색 폴더')
        elif kind == 'link':
            values = (path, '심볼릭 링크 · 독립 저장소 없음', f'`{cell(target)}`', '기존 경로 호환용; 대상과 같은 파일을 가리킴')
        else:
            remote = remotes[rel]
            slug = remote_slug(remote)
            if slug:
                item = info[slug]
                label = {'public': '공개 (public)', 'private': '비공개 (private)', 'internal': '내부 공개 (internal)'}[item['visibility']]
                values = (path, f'독립 Git 저장소 · {label}', f"[{item['full_name']}]({item['html_url']})", cell(item['description']) or 'GitHub 설명 미등록')
            else:
                values = (path, '독립 Git 저장소 · GitHub 공개 여부 확인 대상 아님', f'`{cell(remote)}`' if remote else 'origin 없음', '로컬 Git 저장소' if not remote else 'GitHub 외 원격 또는 지원하지 않는 URL')
        lines.append('| ' + ' | '.join(values) + ' |')
    lines += ['', '공개 여부는 `origin`에 연결된 GitHub 저장소 API에서 확인합니다. 조회 실패 시 기존 표를 유지하고 점검 실패를 알립니다.', END]
    return '\n'.join(lines), repos


def refreshed(old, block):
    if old.count(START) != 1 or old.count(END) != 1:
        raise RuntimeError('README must contain exactly one inventory marker pair')
    before, remainder = old.split(START)
    _, after = remainder.split(END)
    return before + block + after


def atomic_write(path, content):
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.workspace-readme-')
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.chmod(name, path.stat().st_mode & 0o777 if path.exists() else 0o644)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def install_hooks(root, repos):
    script = shlex.quote(str(Path(__file__).resolve()))
    for rel in repos:
        repo = root / rel
        hook_dir = Path(run(['git', 'rev-parse', '--git-path', 'hooks'], repo))
        if not hook_dir.is_absolute():
            hook_dir = repo / hook_dir
        hook_dir = hook_dir.resolve()
        # Never modify shared/global hooks or hooks outside the requested workspace.
        if not hook_dir.is_relative_to(root):
            raise RuntimeError(f'{rel}: hooks directory outside workspace; manual integration required')
        hook_dir.mkdir(parents=True, exist_ok=True)
        hook = hook_dir / 'pre-push'
        original = hook_dir / 'pre-push.workspace-readme-original'
        if hook.is_symlink() or original.is_symlink():
            raise RuntimeError(f'{rel}: symlinked hook requires manual integration')
        if hook.exists() and HOOK_MARKER not in hook.read_text():
            if original.exists():
                raise RuntimeError(f'{rel}: existing hook backup found; refusing to overwrite')
            hook.rename(original)
        content = f'''#!/bin/sh
{HOOK_MARKER}
# Check before the push; leave stdin untouched for any previous hook.
if ! python3 {script} --root {shlex.quote(str(root))} --update </dev/null; then
    echo '[workspace-readme] 점검 실패: 기존 README 유지. 수동 재점검이 필요합니다.' >&2
fi
if [ -x {shlex.quote(str(original))} ]; then
    exec {shlex.quote(str(original))} "$@"
fi
exit 0
'''
        if not hook.exists() or hook.read_text() != content:
            atomic_write(hook, content)
            hook.chmod(0o755)
        print(f'[workspace-readme] hook installed: {rel}', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--update', action='store_true', help='write changed inventory only')
    parser.add_argument('--install-hooks', action='store_true', help='install local pre-push hooks; preserve existing hooks')
    args = parser.parse_args()
    root = args.root.resolve()
    readme = root / 'README.md'
    block, repos = inventory(root)
    old = readme.read_text()
    new = refreshed(old, block)
    changed = new != old
    if changed:
        if args.update:
            atomic_write(readme, new)
            print(f'[workspace-readme] UPDATED: {readme}', file=sys.stderr)
        else:
            sys.stdout.writelines(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='README.md', tofile='README.md (current inventory)'))
            print('[workspace-readme] UPDATE NEEDED: run with --update', file=sys.stderr)
    else:
        print('[workspace-readme] OK: README inventory is current', file=sys.stderr)
    if args.install_hooks:
        install_hooks(root, repos)
    return 1 if changed and not args.update else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f'[workspace-readme] ERROR: {error}', file=sys.stderr)
        sys.exit(2)
