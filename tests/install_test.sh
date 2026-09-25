#!/usr/bin/env bash
# Hermetic tests for install.sh and scripts/transcriber-cli. Go, git, ffmpeg and
# ffprobe are replaced with fakes, so no network access or toolchain is needed.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

pass() { printf 'ok   %s\n' "$1"; }
flunk() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
quiet() { "$@" >/dev/null 2>&1; }
not() { ! "$@" >/dev/null 2>&1; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else flunk "$name"; fi; }

# Fake tools --------------------------------------------------------------
fakes="$work/fakes"
mkdir -p "$fakes" "$work/engine/cmd/cli"
touch "$work/engine/go.mod"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fakes/ffmpeg"
cp "$fakes/ffmpeg" "$fakes/ffprobe"
cat > "$fakes/git" <<'FAKE'
#!/usr/bin/env bash
# "clone" copies $FAKE_GIT_SOURCE to the destination; everything else fails.
for arg; do [[ "$arg" == clone ]] && { cp -R "$FAKE_GIT_SOURCE" "${!#}"; exit 0; }; done
exit 1
FAKE
cat > "$fakes/go" <<'FAKE'
#!/usr/bin/env bash
# "build -o <out>" writes a fake engine that reports which credentials it sees.
while (($#)); do [[ "$1" == -o ]] && out="$2"; shift; done
cat > "$out" <<'ENGINE'
#!/usr/bin/env bash
for v in GEMINI_API_KEY META_API_KEY AZURE_SPEECH_KEY AZURE_SPEECH_ENDPOINT; do
  [[ -z "${!v:-}" ]] || echo "env $v"
done
ENGINE
chmod +x "$out"
FAKE
chmod +x "$fakes"/*

new_home() {
  home="$work/home$((++homes))"
  mkdir -p "$home"
}
homes=0

# run_install <extra env...> -- <args...>: run install.sh from the repository file.
run_install() {
  env -i HOME="$home" PATH="$fakes:/usr/bin:/bin" TRANSCRIBE_ENGINE_SOURCE="$work/engine" \
    bash "$repo/install.sh" "$@" </dev/null
}
cli() {
  env -i HOME="$home" PATH="/usr/bin:/bin" "$@"
}

# Tests -------------------------------------------------------------------
new_home
cd "$work"
if output="$(env -i HOME="$home" PATH="$fakes:/usr/bin:/bin" FAKE_GIT_SOURCE="$repo" \
    TRANSCRIBE_ENGINE_SOURCE="$work/engine" bash -s -- --skip-auth < "$repo/install.sh" 2>&1)"; then
  pass 'piped install (curl | bash) succeeds'
else
  flunk 'piped install (curl | bash) succeeds'; printf '%s\n' "$output"
fi
check 'installs wrapper' test -x "$home/.local/bin/transcriber-cli"
check 'installs engine' test -x "$home/.local/share/transcribe-for-agents/transcriber-cli.bin"
check 'installs Claude Code skill' test -f "$home/.claude/skills/transcribe-for-agents/SKILL.md"
check 'installs Codex skill in ~/.agents/skills' test -f "$home/.agents/skills/transcribe-for-agents/SKILL.md"
check 'does not use the deprecated ~/.codex/skills' test ! -e "$home/.codex/skills/transcribe-for-agents"
check 'warns when bin dir is not on PATH' grep -q 'is not on your PATH' <<<"$output"

check 're-running an identical install succeeds' quiet run_install --skip-auth
check 'identical install makes no backup' test ! -e "$home/.local/share/transcribe-for-agents/backups"

printf 'old line\n' >> "$home/.claude/skills/transcribe-for-agents/SKILL.md"
printf '#!/usr/bin/env bash\n# transcribe-for-agents old wrapper\nexec transcriber-cli.bin\n' > "$home/.local/bin/transcriber-cli"
check 'upgrade over an older install succeeds' quiet run_install --skip-auth
check 'upgrade replaces the skill' diff -q "$repo/plugins/transcription-agent/skills/transcribe-for-agents/SKILL.md" \
  "$home/.claude/skills/transcribe-for-agents/SKILL.md"
check 'upgrade replaces the wrapper' cmp -s "$repo/scripts/transcriber-cli" "$home/.local/bin/transcriber-cli"
check 'upgrade backs up the old skill' test -n "$(find "$home/.local/share/transcribe-for-agents/backups" -name claude-skill)"
check 'upgrade backs up the old wrapper' test -n "$(find "$home/.local/share/transcribe-for-agents/backups" -name transcriber-cli)"
check 'backups stay out of the skills directory' test "$(find "$home/.claude/skills" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1

new_home
mkdir -p "$home/.local/bin"
printf '#!/bin/sh\necho someone else\n' > "$home/.local/bin/transcriber-cli"
check 'refuses to replace an unrelated transcriber-cli' not run_install --skip-auth
check 'unrelated transcriber-cli is untouched' grep -q 'someone else' "$home/.local/bin/transcriber-cli"

new_home
mkdir -p "$home/.claude/skills/transcribe-for-agents"
printf -- '---\nname: something-else\n---\n' > "$home/.claude/skills/transcribe-for-agents/SKILL.md"
check 'refuses to replace an unrelated skill' not run_install --skip-auth --agent claude-code

skill_src="$repo/plugins/transcription-agent/skills/transcribe-for-agents"
backups() { find "$home/.local/share/transcribe-for-agents/backups" -maxdepth 2 -name "$1" 2>/dev/null; }

new_home
mkdir -p "$home/.codex/skills"
cp -R "$skill_src" "$home/.codex/skills/"
check 'installs over a copy in the deprecated Codex folder' quiet run_install --skip-auth
check 'removes the deprecated Codex copy' test ! -e "$home/.codex/skills/transcribe-for-agents"
check 'backs up the deprecated Codex copy' test -n "$(backups codex-legacy-skill)"
check 'installs the current Codex copy' test -f "$home/.agents/skills/transcribe-for-agents/SKILL.md"

new_home
mkdir -p "$home/.codex/skills" "$home/elsewhere"
cp -R "$skill_src" "$home/elsewhere/"
ln -s "$home/elsewhere/transcribe-for-agents" "$home/.codex/skills/transcribe-for-agents"
check 'warns about a symlinked deprecated Codex copy' \
  grep -q 'is a symlink from another installer' <<<"$(run_install --skip-auth 2>&1)"
check 'leaves the symlinked deprecated Codex copy alone' test -L "$home/.codex/skills/transcribe-for-agents"

new_home
mkdir -p "$home/.claude/skills"
cp -R "$skill_src" "$home/.claude/skills/"
printf '{\n  "enabledPlugins": {\n    "transcription-agent@transcription-agent-tools": true\n  }\n}\n' > "$home/.claude/settings.json"
check 'reports that the Claude Code plugin provides the skill' \
  grep -q 'Claude Code: the transcription-agent@transcription-agent-tools plugin provides the skill' <<<"$(run_install --skip-auth 2>&1)"
check 'no standalone Claude Code copy while the plugin is enabled' test ! -e "$home/.claude/skills/transcribe-for-agents"
check 'backs up the old Claude Code copy' test -n "$(backups claude-skill)"
check 'still installs the Codex copy' test -f "$home/.agents/skills/transcribe-for-agents/SKILL.md"

new_home
mkdir -p "$home/.claude"
printf '{"enabledPlugins":{"transcription-agent@transcription-agent-tools":false}}\n' > "$home/.claude/settings.json"
quiet run_install --skip-auth --agent claude-code
check 'a disabled Claude Code plugin does not skip the skill' test -f "$home/.claude/skills/transcribe-for-agents/SKILL.md"

new_home
mkdir -p "$home/.codex"
printf '[plugins."other@x"]\nenabled = true\n\n[plugins."transcription-agent@transcription-agent-tools"]\nenabled = true\n' > "$home/.codex/config.toml"
quiet run_install --skip-auth --agent codex
check 'no standalone Codex copy while the Codex plugin is enabled' test ! -e "$home/.agents/skills/transcribe-for-agents"
printf '[plugins."transcription-agent@transcription-agent-tools"]\nenabled = false\n[plugins."other@x"]\nenabled = true\n' > "$home/.codex/config.toml"
quiet run_install --skip-auth --agent codex
check 'a disabled Codex plugin does not skip the skill' test -f "$home/.agents/skills/transcribe-for-agents/SKILL.md"

new_home
mkdir -p "$home/.claude" "$home/.codex"
printf '{"enabledPlugins":{"transcription-agent@transcription-agent-tools":true}}\n' > "$home/.claude/settings.json"
printf '[plugins."transcription-agent@transcription-agent-tools"]\nenabled = true\n' > "$home/.codex/config.toml"
check 'installs only the CLI when both plugins are enabled' quiet run_install --skip-auth
check 'CLI is installed when both plugins are enabled' test -x "$home/.local/bin/transcriber-cli"

new_home
run_install --skip-auth >/dev/null 2>&1
wrapper="$home/.local/bin/transcriber-cli"
config="$home/.config/transcribe-for-agents"
check 'status: nothing configured' grep -q 'gemini: not configured' <<<"$(cli "$wrapper" auth status)"
check 'status: microsoft key without endpoint is incomplete' \
  grep -q 'microsoft: incomplete' <<<"$(cli AZURE_SPEECH_KEY=k "$wrapper" auth status microsoft || true)"
check 'status <provider> exits 1 when not configured' not cli "$wrapper" auth status meta
check 'status rejects an unknown provider' not cli "$wrapper" auth status openai

mkdir -p "$config" && chmod 700 "$config"
for name in gemini.key meta.key microsoft.key microsoft.endpoint; do printf 'secret' > "$config/$name"; done
check 'status: microsoft from key file plus env endpoint' grep -q 'key via local file, endpoint via environment' \
  <<<"$(rm "$config/microsoft.endpoint"; cli AZURE_SPEECH_ENDPOINT=https://x.example "$wrapper" auth status microsoft)"
printf 'https://x.example' > "$config/microsoft.endpoint"
check 'status <provider> exits 0 when configured' quiet cli "$wrapper" auth status gemini

check 'default model exports only the Gemini key' test "$(cli "$wrapper" -i a.m4a)" = 'env GEMINI_API_KEY'
check 'Meta model exports only the Meta key' \
  test "$(cli "$wrapper" -i a.m4a --model muse-voice-transcribe-1.0)" = 'env META_API_KEY'
check 'Microsoft model exports only Azure settings' \
  test "$(cli "$wrapper" -model=MAI-Transcribe-2 -i a.m4a | tr '\n' ' ')" = 'env AZURE_SPEECH_KEY env AZURE_SPEECH_ENDPOINT '
check 'default model is accepted when named' \
  test "$(cli "$wrapper" -model gemini-3.5-transcribe -i a.m4a)" = 'env GEMINI_API_KEY'
for model in gemini-3.8-flash gemini-3.1-flash-lite muse-voice-transcribe-2.0 MAI-Transcribe-1.5 whisper-1; do
  check "rejects unsupported model $model" not cli "$wrapper" -model "$model" -i a.m4a
done
check 'unsupported model error names the supported models' \
  grep -q 'use gemini-3.5-transcribe, muse-voice-transcribe-1.0, or MAI-Transcribe-2' <<<"$(cli "$wrapper" --model=x -i a.m4a 2>&1 || true)"
check 'unselected provider keys from the environment are removed' \
  test "$(cli GEMINI_API_KEY=g META_API_KEY=m AZURE_SPEECH_KEY=a AZURE_SPEECH_ENDPOINT=https://x.example "$wrapper" -i a.m4a)" = 'env GEMINI_API_KEY'
check 'environment key for the selected provider is kept' \
  test "$(cli META_API_KEY=m GEMINI_API_KEY=g "$wrapper" -model muse-voice-transcribe-1.0 -i a.m4a)" = 'env META_API_KEY'
check 'a flag value that looks like -model is not a model' \
  test "$(cli "$wrapper" -instructions '--model=example' -version)" = 'env GEMINI_API_KEY'
check 'a flag value equal to -model is skipped' \
  test "$(cli "$wrapper" -topic -model -model muse-voice-transcribe-1.0 -i a.m4a)" = 'env META_API_KEY'
check 'boolean flags do not consume the next argument' \
  test "$(cli "$wrapper" -version -judge=false --model muse-voice-transcribe-1.0)" = 'env META_API_KEY'
check 'the last -model wins' \
  test "$(cli "$wrapper" -model MAI-Transcribe-2 -model=muse-voice-transcribe-1.0 -i a.m4a)" = 'env META_API_KEY'
check 'flag parsing stops at the first non-flag argument' \
  test "$(cli "$wrapper" -i a.m4a extra -model MAI-Transcribe-2)" = 'env GEMINI_API_KEY'
check 'flag parsing stops at --' \
  test "$(cli "$wrapper" -i a.m4a -- -model whisper-1)" = 'env GEMINI_API_KEY'
check 'saved key files are owner-only' test -n "$(find "$config/gemini.key" -perm 600)"

check 'installer reports an already saved key instead of prompting' \
  grep -q 'gemini: configured via local file' <<<"$(run_install 2>&1)"

check 'auth remove deletes the saved key' quiet cli "$wrapper" auth remove meta
check 'meta key file is gone' test ! -e "$config/meta.key"

printf '\n%d failure(s)\n' "$failures"
((failures == 0))
