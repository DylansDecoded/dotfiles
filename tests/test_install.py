"""Exercise the mise setup tasks without changing the user's home."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
TASKS = REPO / "mise-tasks"


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = {**os.environ, "HOME": str(self.home)}
        self.env["PATH"] = str(self.bin) + os.pathsep + os.environ["PATH"]

    def command(self, *args):
        return subprocess.run(
            args, cwd=REPO, env=self.env, capture_output=True, text=True
        )

    def stub(self, name, script):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + script + "\n")
        path.chmod(0o755)

    def secrets(self, script):
        self.stub("op", "exit 0")
        self.stub("sops", script)
        return self.command(str(TASKS / "secrets"))

    def test_secrets_accepts_desktop_access_without_cli_session(self):
        self.env["OP_AGE_REF"] = "op://Test Vault/sops/key"
        self.stub(
            "op",
            'case "$1" in\n'
            '  whoami) echo "account is not signed in" >&2; exit 1 ;;\n'
            '  read) [[ "$2" == "$OP_AGE_REF" ]] || exit 1; printf "private-key-marker" ;;\n'
            '  *) exit 1 ;;\n'
            'esac',
        )
        self.stub("sops", 'printf \'{"VALUE":"decrypted"}\'')
        result = self.command(str(TASKS / "secrets"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / ".config/secrets/env.sh").exists())
        self.assertNotIn("private-key-marker", result.stdout + result.stderr)

    def test_secrets_reports_key_access_error_and_preserves_existing_file(self):
        output = self.home / ".config/secrets/env.sh"
        output.parent.mkdir(parents=True)
        output.write_text("export EXISTING=value\n")
        self.stub(
            "op",
            'case "$1" in\n'
            '  read) echo "vault access denied" >&2; exit 1 ;;\n'
            '  *) exit 0 ;;\n'
            'esac',
        )
        self.stub("sops", 'touch "$HOME/sops-called"; exit 1')
        result = self.command(str(TASKS / "secrets"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("vault access denied", result.stderr)
        self.assertEqual(output.read_text(), "export EXISTING=value\n")
        self.assertFalse((self.home / "sops-called").exists())

    def test_failed_decryption_preserves_existing_secrets(self):
        output = self.home / ".config/secrets/env.sh"
        output.parent.mkdir(parents=True)
        output.write_text("export EXISTING=value\n")
        result = self.secrets('printf \'{"PARTIAL":"value"}\'; exit 1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(output.read_text(), "export EXISTING=value\n")
        self.assertEqual(list(output.parent.glob("env.sh.*")), [])

    def test_secrets_are_quoted_and_private(self):
        value = "spaces 'quotes' $(touch injected) $HOME\nsecond line"
        self.env["TEST_SECRET_JSON"] = json.dumps({"VALUE": value})
        result = self.secrets('printf "%s" "$TEST_SECRET_JSON"')
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.home / ".config/secrets/env.sh"
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)
        loaded = self.command(
            "/bin/bash", "-c", 'source "$1"; printf "%s" "$VALUE"', "--", str(output)
        )
        self.assertEqual(loaded.returncode, 0, loaded.stderr)
        self.assertEqual(loaded.stdout, value)
        self.assertFalse((REPO / "injected").exists())

    def test_invalid_variable_name_is_not_published(self):
        self.env["TEST_SECRET_JSON"] = json.dumps({"INVALID-NAME": "value"})
        result = self.secrets('printf "%s" "$TEST_SECRET_JSON"')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / ".config/secrets/env.sh").exists())

    def test_bootstrap_attempts_remaining_steps_after_failure(self):
        self.stub(
            "mise",
            'printf "%s\\n" "$2" >> "$HOME/attempted"\n'
            '[[ "$2" != shell-plugins ]]',
        )
        result = self.command(str(TASKS / "bootstrap"))
        self.assertNotEqual(result.returncode, 0)
        attempted = (self.home / "attempted").read_text().splitlines()
        self.assertIn("shell-plugins", attempted)
        self.assertIn("claude-plugins", attempted)
        self.assertEqual(attempted[-1], "secrets")
        self.assertIn("mise run shell-plugins", result.stderr)

    def test_bootstrap_succeeds_when_all_steps_succeed(self):
        self.stub("mise", "exit 0")
        result = self.command(str(TASKS / "bootstrap"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Done.", result.stdout)

    def test_grok_installer_preserves_configs_and_publishes_valid_binary(self):
        config = self.home / "tracked-grok.toml"
        config.write_text("tracked config\n")
        (self.home / ".grok").mkdir()
        (self.home / ".grok/config.toml").symlink_to(config)
        fish = self.home / ".config/fish/completions/grok.fish"
        fish.parent.mkdir(parents=True)
        fish.write_text("tracked completion\n")
        self.env["PATH"] = str(self.bin) + ":/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        self.stub("mise", "exit 0")
        self.stub(
            "curl",
            "cat <<'INSTALLER'\n"
            'mkdir -p "$HOME/.grok/bin" "$HOME/.grok/downloads" "$HOME/.grok/completions" "$HOME/.config/fish/completions"\n'
            'printf "#!/bin/sh\\nprintf grok-test\\n" > "$HOME/.grok/downloads/grok-test"\n'
            'chmod +x "$HOME/.grok/downloads/grok-test"\n'
            'ln -s ../downloads/grok-test "$HOME/.grok/bin/grok"\n'
            'printf "installer config\\n" > "$HOME/.grok/config.toml"\n'
            'printf "installer completion\\n" > "$HOME/.config/fish/completions/grok.fish"\n'
            "INSTALLER",
        )
        result = self.command(str(TASKS / "grok-cli"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / ".grok/config.toml").is_symlink())
        self.assertEqual(config.read_text(), "tracked config\n")
        self.assertEqual(fish.read_text(), "tracked completion\n")
        binary = self.command(str(self.home / ".grok/bin/grok"))
        self.assertEqual(binary.returncode, 0, binary.stderr)
        self.assertEqual(binary.stdout, "grok-test")


if __name__ == "__main__":
    unittest.main()
