# Transcription Agent plugin

A shared Claude Code and Codex skill for [Transcription Agent](https://github.com/cyanxxy/transcription-agent-go). It turns local MP3, WAV, M4A, FLAC, or OGG recordings into TXT, SRT, or JSON transcripts using the existing `transcriber-cli` program. The plugin repo contains no model API keys or audio files.

## 1. Install the CLI

The plugin calls Transcription Agent's CLI, so build it from the [source repository](https://github.com/cyanxxy/transcription-agent-go) and put the binary on `PATH`:

```bash
git clone https://github.com/cyanxxy/transcription-agent-go.git
cd transcription-agent-go
make bin/transcriber-cli
mkdir -p "$HOME/.local/bin"
cp bin/transcriber-cli "$HOME/.local/bin/transcriber-cli"
```

This requires Go 1.26+, `ffmpeg`, and `ffprobe`. If the binary lives elsewhere, set `TRANSCRIBER_CLI` to its absolute path in the environment where Claude Code or Codex runs.

## 2. Set up credentials

From this plugin repository, run the interactive setup command for the provider you use:

```bash
python3 plugins/transcription-agent/scripts/setup.py --provider gemini
python3 plugins/transcription-agent/scripts/setup.py --check
```

Use `--provider meta` or `--provider microsoft` for the other speech models. Microsoft setup asks for its Speech resource HTTPS endpoint too. The command hides key input and saves credentials as plaintext in `~/.config/transcription-agent-plugin/credentials.json` with owner-only permissions. Set `XDG_CONFIG_HOME` or `TRANSCRIPTION_AGENT_CREDENTIALS_FILE` to choose a different location. Run `--clear --provider gemini` to remove a saved key.

Existing `GEMINI_API_KEY`, `META_API_KEY`, `AZURE_SPEECH_KEY`, and `AZURE_SPEECH_ENDPOINT` environment variables take precedence over saved credentials. For CI, use environment variables instead of interactive setup. Never commit keys to this repository.

## 3. Load the plugin

### Claude Code

For local development:

```bash
claude --plugin-dir ./plugins/transcription-agent
```

Or register this repository's marketplace and install its plugin:

```bash
claude plugin marketplace add .
claude plugin install transcription-agent@transcription-agent-tools
```

Then ask for a transcript or invoke `/transcription-agent:transcribe /absolute/path/to/meeting.m4a`.

### Codex

Register this repository's Codex marketplace, then install the plugin:

```bash
codex plugin marketplace add .
codex plugin add transcription-agent@transcription-agent-tools
```

Start a new Codex task after installation and ask it to transcribe a local recording. The plugin's shared skill is in [`plugins/transcription-agent/skills/transcribe/SKILL.md`](plugins/transcription-agent/skills/transcribe/SKILL.md).

## Direct launcher usage

```bash
python3 plugins/transcription-agent/scripts/transcribe.py \
  --input /absolute/path/to/meeting.m4a \
  --output /absolute/path/to/meeting.srt \
  --format srt
```

The default model is `gemini-3.5-transcribe`. Select `muse-voice-transcribe-1.0` or `MAI-Transcribe-2` with `--model` when using Meta or Microsoft. The launcher refuses to replace an existing output file unless you pass `--overwrite`.
