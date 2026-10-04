"""Migration destinations must retain hierarchy and never clone into backups."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT=Path(__file__).resolve().parent.parent/'migration/resolve-target.py'

class TargetTests(unittest.TestCase):
    def run_case(self, records, group='personal'):
        with tempfile.TemporaryDirectory() as tmp:
            root=(Path(tmp)/'Codes').resolve();root.mkdir()
            manifest=Path(tmp)/'manifest.json';manifest.write_text(json.dumps({'repos':records}))
            result=subprocess.run([sys.executable,str(SCRIPT),str(root),group,'example','https://github.com/example/example.git'],env={**os.environ,'MIGRATION_MANIFEST':str(manifest)},capture_output=True,text=True)
            return result,root
    def test_manifest_hierarchy_ignores_worktree_and_backup(self):
        records=[{'path':'personal/content/site','origin':'git@github.com:example/example.git'},
                 {'path':'personal/content/reader','origin':'https://github.com/example/example.git','is_worktree':True},
                 {'path':'others/_backups/personal/example','origin':'https://github.com/example/example.git'}]
        result,root=self.run_case(records)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.strip(),str(root/'personal/content/site'))
    def test_new_personal_repo_stays_inside_project_area(self):
        result,root=self.run_case([])
        self.assertEqual(result.stdout.strip(),str(root/'personal/projects/example'))
    def test_backup_group_is_rejected(self):
        result,_=self.run_case([],group='others/_backups')
        self.assertNotEqual(result.returncode,0)
    def test_manifest_cannot_escape_workspace(self):
        result,_=self.run_case([{'path':'../../outside','origin':'https://github.com/example/example.git'}])
        self.assertNotEqual(result.returncode,0)

if __name__=='__main__':unittest.main()
