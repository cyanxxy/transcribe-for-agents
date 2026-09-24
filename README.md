# Transcription Agent plugin

A shared Claude Code and Codex skill for [Transcription Agent](https://github.com/cyanxxy/transcription-agent-go). It turns local MP3, WAV, M4A, FLAC, or OGG recordings into TXT, SRT, or JSON transcripts using the Go `transcriber-cli` program. The plugin has no Python runtime or stored keys.

## 1. Install the CLI

Build the CLI from the [Transcription Agent source](https://github.com/cyanxxy/transcription-agent-go) and put it on `PATH`:

```bash
git clone https://github.com/cyanxxy/transcription-agent-go.git
cd transcription-agent-go
make bin/transcriber-cli
mkdir -p "$HOME/.local/bin"
cp bin/transcriber-cli "$HOME/.local/bin/transcriber-cli"
```

Make sure `~/.local/bin` is on the `PATH` seen by Claude Code or Codex, or set `TRANSCRIBER_CLI` to the binary's absolute path in that environment. The CLI requires Go 1.26+ to build. Transcription also requires `ffmpeg` and `ffprobe`.

## 2. Set up credentials

Run the CLI setup command in your own terminal:

```bash
transcriber-cli auth set gemini
transcriber-cli auth status
```

Use `auth set meta` or `auth set microsoft` for the other speech models. Microsoft setup asks for its Speech resource HTTPS endpoint too. The Go CLI hides key input and saves plaintext credentials in an owner-only file under the OS user config directory at `transcription-agent/credentials.json`. Set `TRANSCRIBER_CREDENTIALS_FILE` to an absolute path to use another location. Run `auth remove <provider>` to delete a saved key.

Environment variables `GEMINI_API_KEY`, `META_API_KEY`, `AZURE_SPEECH_KEY`, and `AZURE_SPEECH_ENDPOINT` take precedence over saved values. For CI, use environment variables instead of interactive setup. Never commit keys to this repository.

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

Start a new Codex task after installation and ask it to transcribe a local recording. The shared instructions are in [the transcribe skill](plugins/transcription-agent/skills/transcribe/SKILL.md).

## Direct usage

```bash
transcriber-cli -i /absolute/path/to/meeting.m4a -o /absolute/path/to/meeting.srt -format srt
```

The default model is `gemini-3.5-transcribe`. Select `muse-voice-transcribe-1.0` or `MAI-Transcribe-2` with `--model` when using Meta or Microsoft. Check whether an output file already exists before using `-o`: the CLI replaces it.
