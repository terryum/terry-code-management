"""Regression checks for nested active repositories and excluded preservation trees."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name('discover-repos.sh')

class DiscoveryTests(unittest.TestCase):
    def test_without_machine_exclusions(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'personal/projects/example/.git').mkdir(parents=True)
            result = subprocess.check_output(['bash', str(SCRIPT)], env={**os.environ,
                'CODES_ROOT': tmp, 'CODES_EXCLUDE_FILE': str(root / 'absent.txt')}, text=True)
            self.assertEqual(result.strip(), str(root / 'personal/projects/example'))

    def test_nested_repos_worktrees_and_exclusions(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            active = ['personal/terryum-ai/site', 'personal/terryum-ai/surveys/framework',
                      'personal/projects/kamp2026', '.dev-log', 'robotics/reader']
            excluded = ['others/_backups/cosmax/project', 'others/management/.local/operations/repo',
                        'personal/apps/app/node_modules/package', 'robotics/reader/.cache/assets/repo',
                        'others/ongoing-operation/work/repo', 'personal/terryum-ai/site/.tmp/publish']
            for rel in active + excluded:
                (root / rel / '.git').mkdir(parents=True)
            worktree = root / 'robotics/reader-worktree'
            worktree.mkdir(); (worktree / '.git').write_text('gitdir: ../reader/.git/worktrees/reader-worktree\n')
            (root / 'linked-backup').symlink_to(root / 'others/_backups', target_is_directory=True)
            excludes = root / 'exclude-paths.txt'
            excludes.write_text('others/ongoing-operation\n')
            result = subprocess.check_output(['bash', str(SCRIPT)], env={**os.environ, 'CODES_ROOT': tmp, 'CODES_EXCLUDE_FILE': str(excludes)}, text=True)
            actual = {str(Path(p).relative_to(root)) for p in result.splitlines()}
            self.assertEqual(actual, set(active) | {'robotics/reader-worktree'})

if __name__ == '__main__':
    unittest.main()
