"""Behavior tests for credential setup and the CLI launcher."""

from __future__ import annotations

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1] / "plugins" / "transcription-agent" / "scripts"
sys.path.insert(0, str(SCRIPTS))

import credentials  # noqa: E402
import setup  # noqa: E402


class PluginTests(unittest.TestCase):
    def test_setup_saves_owner_only_key_without_echoing_it(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config" / "credentials.json"
            output = io.StringIO()
            with (
                patch.dict(os.environ, {"TRANSCRIPTION_AGENT_CREDENTIALS_FILE": str(path)}),
                patch.object(setup, "getpass", return_value="test-gemini-key"),
                redirect_stdout(output),
            ):
                self.assertEqual(setup.main(["--provider", "gemini"]), 0)
                self.assertEqual(credentials.load_credentials()["gemini"]["GEMINI_API_KEY"], "test-gemini-key")
            self.assertNotIn("test-gemini-key", output.getvalue())
            if os.name == "posix":
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_launcher_passes_saved_key_only_in_child_environment(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            audio = root / "meeting with spaces.m4a"
            audio.write_bytes(b"test audio")
            transcript = root / "meeting.json"
            fake_cli = root / "fake-cli"
            fake_cli.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, pathlib, sys\n"
                "a = sys.argv[1:]\n"
                "pathlib.Path(a[a.index('-o') + 1]).write_text(json.dumps({"
                "'args': a, 'key': os.environ.get('GEMINI_API_KEY')}))\n"
            )
            fake_cli.chmod(0o755)
            config = root / "config" / "credentials.json"
            environment = dict(os.environ)
            environment.pop("GEMINI_API_KEY", None)
            environment.update({
                "TRANSCRIPTION_AGENT_CREDENTIALS_FILE": str(config),
                "TRANSCRIBER_CLI": str(fake_cli),
            })
            with patch.dict(os.environ, environment, clear=True):
                credentials.save_credentials({"gemini": {"GEMINI_API_KEY": "saved-key"}})
            command = [
                sys.executable, str(SCRIPTS / "transcribe.py"),
                "--input", str(audio), "--output", str(transcript), "--format", "json",
            ]
            result = subprocess.run(command, env=environment, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(transcript.read_text())
            self.assertEqual(data["key"], "saved-key")
            self.assertNotIn("saved-key", data["args"])
            self.assertIn(str(audio), data["args"])

            existing = subprocess.run(command, env=environment, capture_output=True, text=True)
            self.assertEqual(existing.returncode, 2)
            self.assertIn("output already exists", existing.stderr)

    def test_microsoft_endpoint_requires_https_origin(self) -> None:
        self.assertTrue(setup.valid_endpoint("https://example.cognitiveservices.azure.com"))
        self.assertFalse(setup.valid_endpoint("http://example.com"))
        self.assertFalse(setup.valid_endpoint("https://example.com/speech/path"))

    def test_credentials_override_must_be_absolute(self) -> None:
        with patch.dict(os.environ, {"TRANSCRIPTION_AGENT_CREDENTIALS_FILE": "credentials.json"}):
            with self.assertRaisesRegex(ValueError, "absolute path"):
                credentials.credentials_path()


if __name__ == "__main__":
    unittest.main()
