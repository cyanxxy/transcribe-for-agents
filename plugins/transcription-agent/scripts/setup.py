#!/usr/bin/env python3
"""Set up transcription provider credentials for this user."""

from __future__ import annotations

import argparse
from getpass import getpass
import os
import sys
from urllib.parse import urlsplit

from credentials import PROVIDERS, credentials_path, load_credentials, provider_environment, save_credentials


def valid_endpoint(value: str) -> bool:
    parts = urlsplit(value)
    return (
        parts.scheme == "https"
        and bool(parts.netloc)
        and parts.path in ("", "/")
        and not parts.query
        and not parts.fragment
        and not parts.username
        and not parts.password
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", choices=tuple(PROVIDERS), default="gemini")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check", action="store_true", help="Show which providers are configured")
    action.add_argument("--clear", action="store_true", help="Remove saved credentials for this provider")
    args = parser.parse_args(argv)

    try:
        if args.check:
            for provider in PROVIDERS:
                values = provider_environment(provider, os.environ)
                status = "configured" if all(values.values()) else "missing credentials"
                print(f"{provider}: {status}")
            return 0

        saved = load_credentials()
        if args.clear:
            saved.pop(args.provider, None)
            path = save_credentials(saved)
            print(f"Removed saved {args.provider} credentials from {path}")
            return 0

        key_label = {
            "gemini": "Gemini API key",
            "meta": "Meta API key",
            "microsoft": "Azure Speech key",
        }[args.provider]
        key = getpass(f"{key_label}: ").strip()
        if not key:
            raise ValueError("API key cannot be empty")
        values = {PROVIDERS[args.provider][0]: key}
        if args.provider == "microsoft":
            endpoint = input("Azure Speech endpoint (HTTPS origin): ").strip().rstrip("/")
            if not valid_endpoint(endpoint):
                raise ValueError("Azure Speech endpoint must be an HTTPS origin without a path")
            values["AZURE_SPEECH_ENDPOINT"] = endpoint

        saved[args.provider] = values
        path = save_credentials(saved)
        print(f"Saved {args.provider} credentials to {path} (owner-only access)")
        return 0
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
