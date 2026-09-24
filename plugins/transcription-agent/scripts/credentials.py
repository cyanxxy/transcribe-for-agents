"""Local, per-user credentials for the transcription plugin."""

from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile


PROVIDERS = {
    "gemini": ("GEMINI_API_KEY",),
    "meta": ("META_API_KEY",),
    "microsoft": ("AZURE_SPEECH_KEY", "AZURE_SPEECH_ENDPOINT"),
}


def credentials_path() -> Path:
    override = os.environ.get("TRANSCRIPTION_AGENT_CREDENTIALS_FILE")
    if override:
        path = Path(override).expanduser()
        if not path.is_absolute():
            raise ValueError("TRANSCRIPTION_AGENT_CREDENTIALS_FILE must be an absolute path")
        return path
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return config_home / "transcription-agent-plugin" / "credentials.json"


def load_credentials() -> dict[str, dict[str, str]]:
    path = credentials_path()
    if not path.exists():
        return {}
    if not path.is_file():
        raise ValueError(f"credentials path is not a file: {path}")
    if os.name == "posix" and path.stat().st_mode & 0o077:
        raise ValueError(f"credentials file permissions are too open; run chmod 600 {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read credentials file: {path}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"invalid credentials file: {path}")
    result: dict[str, dict[str, str]] = {}
    for provider, values in data.items():
        if provider not in PROVIDERS or not isinstance(values, dict):
            raise ValueError(f"invalid credentials file: {path}")
        if not all(isinstance(k, str) and isinstance(v, str) for k, v in values.items()):
            raise ValueError(f"invalid credentials file: {path}")
        result[provider] = values
    return result


def save_credentials(data: dict[str, dict[str, str]]) -> Path:
    path = credentials_path()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    file_descriptor, temporary_name = tempfile.mkstemp(prefix=".credentials-", dir=path.parent)
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_name, 0o600)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
    return path


def provider_environment(provider: str, environment: dict[str, str]) -> dict[str, str]:
    required = PROVIDERS[provider]
    saved = {} if all(environment.get(key) for key in required) else load_credentials().get(provider, {})
    return {
        key: environment.get(key) or saved.get(key, "")
        for key in required
    }
