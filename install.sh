#!/usr/bin/env bash
set -euo pipefail

repo_url='https://github.com/cyanxxy/transcribe-for-agents.git'
engine_url='https://github.com/cyanxxy/transcription-agent-go.git'
engine_ref='v1.1.0'
engine_sha='db8313a7ef90a5d20e027328d0cab8d20fc28e8d'
agent='both'
provider='gemini'
skip_auth=false

usage() {
  cat <<'USAGE'
Usage: bash install.sh [--agent claude-code|codex|both] [--provider gemini|meta|microsoft] [--skip-auth]

Installs the transcribe-for-agents skill and Go transcription CLI into your user account.
USAGE
}

while (($#)); do
  case "$1" in
    --agent) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; agent="$2"; shift 2 ;;
    --provider) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; provider="$2"; shift 2 ;;
    --skip-auth) skip_auth=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$agent" in claude-code|codex|both) ;; *) usage >&2; exit 2 ;; esac
case "$provider" in gemini|meta|microsoft) ;; *) usage >&2; exit 2 ;; esac

fail() { printf 'install: %s\n' "$*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required"; }
has_tty() { [[ -t 0 ]] || { : < /dev/tty; } 2>/dev/null; }

install_prerequisites() {
  local missing=()
  command -v go >/dev/null 2>&1 || missing+=(go)
  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    missing+=(ffmpeg)
  fi
  ((${#missing[@]} == 0)) && return
  if command -v brew >/dev/null 2>&1 && has_tty; then
    if [[ -t 0 ]]; then
      printf 'Missing %s. Install with Homebrew? [y/N] ' "${missing[*]}" >&2
      IFS= read -r answer || true
    else
      printf 'Missing %s. Install with Homebrew? [y/N] ' "${missing[*]}" > /dev/tty
      IFS= read -r answer < /dev/tty || true
    fi
    if [[ "$answer" == y || "$answer" == Y ]]; then
      brew install "${missing[@]}"
      return
    fi
  fi
  fail "missing ${missing[*]}; install them and run this command again"
}

require_command git
install_prerequisites
require_command go
require_command ffmpeg
require_command ffprobe

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

source_dir="${TRANSCRIBE_INSTALL_SOURCE:-}"
if [[ -z "$source_dir" && -f "$(dirname "${BASH_SOURCE[0]}")/plugins/transcription-agent/skills/transcribe-for-agents/SKILL.md" ]]; then
  source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "$source_dir" ]]; then
  printf 'Fetching the skill...\n'
  git clone --quiet --depth 1 "$repo_url" "$temp_dir/plugin"
  source_dir="$temp_dir/plugin"
fi
skill_dir="$source_dir/plugins/transcription-agent/skills/transcribe-for-agents"
wrapper="$source_dir/scripts/transcriber-cli"
[[ -f "$skill_dir/SKILL.md" && -f "$wrapper" ]] || fail 'skill or CLI wrapper is missing from the source repository'
bin_dir="$HOME/.local/bin"
if [[ -e "$bin_dir/transcriber-cli" || -L "$bin_dir/transcriber-cli" ]]; then
  cmp -s "$wrapper" "$bin_dir/transcriber-cli" ||
    fail "existing CLI differs: $bin_dir/transcriber-cli (move it before installing)"
fi

targets=()
if [[ "$agent" == both || "$agent" == claude-code ]]; then targets+=("$HOME/.claude/skills/transcribe-for-agents"); fi
if [[ "$agent" == both || "$agent" == codex ]]; then targets+=("$HOME/.codex/skills/transcribe-for-agents"); fi
for target in "${targets[@]}"; do
  if [[ -e "$target" || -L "$target" ]]; then
    diff -qr "$skill_dir" "$target" >/dev/null || fail "existing skill differs: $target (remove or back it up before installing)"
  fi
done

engine_source="${TRANSCRIBE_ENGINE_SOURCE:-}"
if [[ -z "$engine_source" ]]; then
  printf 'Fetching transcription engine %s...\n' "$engine_ref"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$engine_ref" "$engine_url" "$temp_dir/engine"
  engine_source="$temp_dir/engine"
  [[ "$(git -C "$engine_source" rev-parse HEAD)" == "$engine_sha" ]] || fail 'release tag does not match the pinned source commit'
fi
[[ -f "$engine_source/go.mod" ]] || fail 'transcription engine source is missing go.mod'

printf 'Building transcriber-cli...\n'
(
  cd "$engine_source"
  CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=$engine_ref" -o "$temp_dir/transcriber-cli.bin" ./cmd/cli
)

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/transcribe-for-agents"
mkdir -p "$data_dir" "$bin_dir"
install -m 755 "$temp_dir/transcriber-cli.bin" "$data_dir/transcriber-cli.bin"
install -m 755 "$wrapper" "$bin_dir/transcriber-cli"
for target in "${targets[@]}"; do
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$(dirname "$target")"
    cp -R "$skill_dir" "$target"
  fi
  printf 'Installed skill: %s\n' "$target"
done

if [[ "$skip_auth" == false ]]; then
  key_variable='GEMINI_API_KEY'
  case "$provider" in
    meta) key_variable='META_API_KEY' ;;
    microsoft) key_variable='AZURE_SPEECH_KEY' ;;
  esac
  if [[ -n "${!key_variable:-}" ]]; then
    printf '%s is already set in this environment.\n' "$key_variable"
  elif has_tty; then
    "$bin_dir/transcriber-cli" auth set "$provider"
  else
    printf 'No terminal available for the API key. Run %s auth set %s later.\n' "$bin_dir/transcriber-cli" "$provider"
  fi
fi

printf '\nReady. Give your agent an audio file and ask it to transcribe it.\n'
printf 'CLI: %s\n' "$bin_dir/transcriber-cli"
printf 'ffmpeg and ffprobe must remain on PATH when the agent runs.\n'
