"""Check directory-scoped gh authentication without real credentials."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
LAUNCHER = REPO / "home/.local/bin/gh"


class GhAccountTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.local_bin = self.home / ".local/bin"
        self.local_bin.mkdir(parents=True)
        (self.local_bin / "gh").symlink_to(LAUNCHER)
        self.vendor_bin = self.home / "vendor/bin"
        self.vendor_bin.mkdir(parents=True)
        binary = self.vendor_bin / "gh"
        binary.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "args = sys.argv[1:]\n"
            "if args[:2] == ['auth', 'token']:\n"
            "    assert 'GH_TOKEN' not in os.environ\n"
            "    assert 'GITHUB_TOKEN' not in os.environ\n"
            "    if os.environ.get('MISSING_ACCOUNT'): sys.exit(1)\n"
            "    print('saved-' + args[args.index('--user') + 1])\n"
            "else:\n"
            "    print(json.dumps({'args': args, 'token': os.getenv('GH_TOKEN'),\n"
            "                      'github_token': os.getenv('GITHUB_TOKEN')}))\n"
            "    sys.exit(int(os.environ.get('GH_TEST_EXIT', '0')))\n"
        )
        binary.chmod(0o755)
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "PATH": f"{self.local_bin}:{self.vendor_bin}:/usr/bin:/bin",
            "GH_TOKEN": "inherited-gh-token",
            "GITHUB_TOKEN": "inherited-github-token",
        }

    def run_gh(self, directory, *args):
        cwd = self.home / directory
        cwd.mkdir(parents=True, exist_ok=True)
        return subprocess.run(
            ["gh", *(args or ("api", "user"))], cwd=cwd, env=self.env,
            text=True, capture_output=True,
        )

    def test_each_tree_selects_its_account_at_root_and_in_subdirectories(self):
        for tree, account in (
            ("personal", "DylansDecoded"),
            ("work/robots-and-pencils", "dylan-robson-rp"),
        ):
            for suffix in ("", "/repo with spaces/src"):
                with self.subTest(tree=tree, suffix=suffix):
                    result = self.run_gh("Projects/" + tree + suffix)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    data = json.loads(result.stdout)
                    self.assertEqual(data["token"], "saved-" + account)
                    self.assertIsNone(data["github_token"])

    def test_other_directories_and_similar_prefixes_keep_existing_behavior(self):
        for directory in (
            "Projects/personal-other", "Projects/work/robots-and-pencils-other",
            "Projects/work/toyota", "dotfiles",
        ):
            with self.subTest(directory=directory):
                result = self.run_gh(directory)
                self.assertEqual(result.returncode, 0, result.stderr)
                data = json.loads(result.stdout)
                self.assertEqual(data["token"], "inherited-gh-token")
                self.assertEqual(data["github_token"], "inherited-github-token")

    def test_symlink_to_project_uses_physical_directory(self):
        project = self.home / "Projects/personal/repo"
        project.mkdir(parents=True)
        (self.home / "shortcut").symlink_to(project)
        result = self.run_gh("shortcut")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["token"], "saved-DylansDecoded")

    def test_missing_account_fails_without_running_requested_command(self):
        self.env["MISSING_ACCOUNT"] = "1"
        result = self.run_gh("Projects/personal")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("No saved token for DylansDecoded", result.stderr)

    def test_login_remains_available_without_saved_account_or_env_token(self):
        self.env["MISSING_ACCOUNT"] = "1"
        result = self.run_gh("Projects/personal", "auth", "login", "--hostname", "github.com")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["args"], ["auth", "login", "--hostname", "github.com"])
        self.assertIsNone(data["token"])
        self.assertIsNone(data["github_token"])

    def test_status_uses_selected_token(self):
        result = self.run_gh("Projects/personal", "auth", "status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["token"], "saved-DylansDecoded")

    def test_arguments_and_exit_code_are_preserved(self):
        self.env["GH_TEST_EXIT"] = "42"
        args = ("issue", "list", "--search", "some words 'quotes' $literal")
        result = self.run_gh("Projects/personal", *args)
        self.assertEqual(result.returncode, 42)
        self.assertEqual(json.loads(result.stdout)["args"], list(args))

    def test_noninteractive_zsh_finds_launcher_before_vendor_binary(self):
        (self.home / ".zshenv").symlink_to(REPO / "home/.zshenv")
        self.env["PATH"] = f"{self.vendor_bin}:/usr/bin:/bin:{self.local_bin}"
        self.env["ZDOTDIR"] = str(self.home)
        result = subprocess.run(
            ["/bin/zsh", "-c", "command -v gh"], env=self.env,
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), str(self.local_bin / "gh"))


if __name__ == "__main__":
    unittest.main()
