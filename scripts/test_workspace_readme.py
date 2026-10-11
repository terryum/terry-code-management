"""Focused checks for inventory correctness and safe Git hook integration."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('workspace_readme', Path(__file__).with_name('workspace-readme.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WorkspaceReadmeTests(unittest.TestCase):
    def test_remote_formats(self):
        for remote in ['https://github.com/example/project.git', 'git@github.com:example/project.git',
                       'ssh://git@github.com/example/project', 'https://github.com/example/project/']:
            self.assertEqual(module.remote_slug(remote), 'example/project')
        self.assertIsNone(module.remote_slug('https://another-host/example/project.git'))

    def test_classification_and_links(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            (root / 'apps' / 'project' / '.git').mkdir(parents=True)
            (root / 'apps' / 'project' / 'src').mkdir()
            (root / 'local').mkdir()
            (root / '.cache').mkdir()
            (root / 'alias').symlink_to('apps/project')
            rows = module.folders(root)
            self.assertIn(('apps/project', 'repo', ''), rows)
            self.assertIn(('local', 'local', ''), rows)
            self.assertIn(('alias', 'link', 'apps/project'), rows)
            self.assertFalse(any('src' in row[0] or '.cache' in row[0] for row in rows))

    def test_visibility_change_and_prose_preservation(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            (root / 'project' / '.git').mkdir(parents=True)
            remote = {'project': 'https://github.com/example/project.git'}
            info = {'example/project': {'visibility': 'public', 'full_name': 'example/project',
                                       'html_url': 'https://github.com/example/project', 'description': 'a | b'}}
            with patch.object(module, 'metadata', return_value=(remote, info)):
                public, _ = module.inventory(root)
                info['example/project']['visibility'] = 'private'
                private, _ = module.inventory(root)
            self.assertNotEqual(public, private)
            self.assertIn('a \\| b', private)
            before = 'manual introduction\n' + public + '\nmanual ending\n'
            after = module.refreshed(before, private)
            self.assertTrue(after.startswith('manual introduction\n'))
            self.assertTrue(after.endswith('\nmanual ending\n'))
            self.assertEqual(module.refreshed(after, private), after)

    def test_hook_chains_original_stdin_and_exit_status(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            repo = root / 'project'
            repo.mkdir()
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            hook = repo / '.git' / 'hooks' / 'pre-push'
            hook.write_text('#!/bin/sh\ncat > hook-input\nprintf "%s\\n" "$@" > hook-args\nexit 7\n')
            hook.chmod(0o755)
            # Stub the check; exercise the actual installed shell wrapper and preserved original.
            checker = root / 'checker.py'
            checker.write_text('raise SystemExit(2)\n')
            with patch.object(module, '__file__', str(checker)):
                module.install_hooks(root, ['project'])
                first = hook.read_bytes()
                module.install_hooks(root, ['project'])
                self.assertEqual(first, hook.read_bytes())
            result = subprocess.run([str(hook), 'origin', 'remote-url'], cwd=repo,
                                    input='refs/heads/main abc refs/heads/main def\n', text=True, capture_output=True)
            self.assertEqual(result.returncode, 7)
            self.assertEqual((repo / 'hook-input').read_text(), 'refs/heads/main abc refs/heads/main def\n')
            self.assertEqual((repo / 'hook-args').read_text(), 'origin\nremote-url\n')
            self.assertIn('점검 실패', result.stderr)

    def test_hook_git_environment_is_isolated(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            repo = root / 'project'
            repo.mkdir()
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            with patch.dict(os.environ, {'GIT_DIR': '/does/not/exist', 'GIT_WORK_TREE': '/does/not/exist'}):
                self.assertEqual(module.run(['git', 'rev-parse', '--show-toplevel'], repo), str(repo))

    def test_failed_metadata_does_not_write_readme(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            readme = root / 'README.md'
            readme.write_text('manual\n' + module.START + '\nold table\n' + module.END + '\n')
            before = readme.read_bytes()
            with patch.object(module, 'metadata', side_effect=RuntimeError('unavailable')):
                with patch('sys.argv', ['workspace-readme.py', '--root', str(root), '--update']):
                    with self.assertRaises(RuntimeError):
                        module.main()
            self.assertEqual(before, readme.read_bytes())


if __name__ == '__main__':
    unittest.main()
