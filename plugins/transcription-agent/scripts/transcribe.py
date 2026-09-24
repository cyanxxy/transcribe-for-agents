#!/usr/bin/env python3
"""Invoke Transcription Agent's CLI from Claude Code or Codex."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from credentials import provider_environment


def find_cli() -> str:
    override = os.environ.get("TRANSCRIBER_CLI")
    if override:
        path = Path(override).expanduser()
        if not path.is_file() or not os.access(path, os.X_OK):
            raise ValueError(f"TRANSCRIBER_CLI is not an executable file: {path}")
        return str(path.resolve())

    installed = shutil.which("transcriber-cli")
    if installed:
        return installed

    local_binary = Path(__file__).resolve().parents[1] / "bin" / "transcriber-cli"
    if local_binary.is_file() and os.access(local_binary, os.X_OK):
        return str(local_binary)

    raise ValueError(
        "transcriber-cli not found; install it on PATH or set TRANSCRIBER_CLI "
        "to the binary from the Transcription Agent repository"
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Local audio file")
    parser.add_argument("--output", type=Path, help="Transcript file; stdout if omitted")
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing output file")
    parser.add_argument("--format", choices=("txt", "srt", "json"), default="txt")
    parser.add_argument(
        "--model",
        choices=("gemini-3.5-transcribe", "muse-voice-transcribe-1.0", "MAI-Transcribe-2", "gemini-3.8-flash", "gemini-3.1-flash-lite"),
        default="gemini-3.5-transcribe",
    )
    parser.add_argument("--topic")
    parser.add_argument("--speakers", help="Comma-separated speaker names")
    parser.add_argument("--terms", help="Comma-separated technical terms")
    parser.add_argument("--language-hints")
    parser.add_argument("--expected-format")
    parser.add_argument("--remove-fillers", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    source = args.input.expanduser().resolve()
    if not source.is_file():
        print(f"error: audio file not found: {source}", file=sys.stderr)
        return 2

    output = args.output.expanduser().resolve() if args.output is not None else None
    if output == source:
        print("error: output must differ from the input audio file", file=sys.stderr)
        return 2
    if output is not None and output.exists() and not args.overwrite:
        print(f"error: output already exists (use --overwrite): {output}", file=sys.stderr)
        return 2

    try:
        cli = find_cli()
        provider = (
            "meta" if args.model == "muse-voice-transcribe-1.0" else
            "microsoft" if args.model == "MAI-Transcribe-2" else "gemini"
        )
        environment = dict(os.environ)
        required = provider_environment(provider, environment)
        missing = [key for key, value in required.items() if not value]
        if missing:
            raise ValueError(
                "missing " + ", ".join(missing) +
                "; run scripts/setup.py --provider " + provider + " or set the environment variables"
            )
        environment.update(required)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    command = [cli, "-i", str(source), "-format", args.format, "--model", args.model]
    if output is not None:
        command.extend(("-o", str(output)))
    for option in ("topic", "speakers", "terms", "language_hints", "expected_format"):
        value = getattr(args, option)
        if value:
            command.extend(("--" + option.replace("_", "-"), value))
    if args.remove_fillers:
        command.append("--remove-fillers")
    return subprocess.call(command, env=environment)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
