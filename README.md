# Transcribe for Agents

A transcription skill for Claude Code, Codex, and other agents supported by the [Skills CLI](https://github.com/vercel-labs/skills). Give your agent a local MP3, WAV, M4A, FLAC, or OGG recording and get a timestamped, speaker-labeled TXT, SRT, or JSON transcript. The skill uses the Go `transcriber-cli` from [Transcription Agent](https://github.com/cyanxxy/transcription-agent-go); this repository contains the agent instructions and plugin manifests, not the transcription engine or API keys.

## Quick install

Choose one installation method for your agent:

```bash
# Skills CLI: Claude Code
npx skills add cyanxxy/transcribe-for-agents --skill transcribe --agent claude-code --global

# Skills CLI: Codex
npx skills add cyanxxy/transcribe-for-agents --skill transcribe --agent codex --global
```

The repository also works as a native plugin marketplace:

```bash
# Claude Code
claude plugin marketplace add cyanxxy/transcribe-for-agents
claude plugin install transcription-agent@transcription-agent-tools

# Codex
codex plugin marketplace add cyanxxy/transcribe-for-agents
codex plugin add transcription-agent@transcription-agent-tools
```

After installing the skill, install `transcriber-cli` and configure one speech provider below. The skill cannot transcribe audio without the CLI and a provider key.

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

### Vercel Skills CLI

The same `transcribe` skill is discoverable by the [Skills CLI](https://github.com/vercel-labs/skills), which can install it directly for Claude Code or Codex. From this repository, check discovery without installing:

```bash
npx skills add . --list
```

To install the skill globally from a local checkout, run one of these commands from this repository:

```bash
npx skills add . --skill transcribe --agent claude-code --global
npx skills add . --skill transcribe --agent codex --global
```

For remote installation, use the `cyanxxy/transcribe-for-agents` commands in Quick install above. The Skills CLI installs the skill instructions; install `transcriber-cli` and set up a provider key with `transcriber-cli auth set` as described above. Use either the plugin marketplace or the Skills CLI for a given agent to avoid installing the same skill twice.

## Direct usage

```bash
transcriber-cli -i /absolute/path/to/meeting.m4a -o /absolute/path/to/meeting.srt -format srt
```

The default model is `gemini-3.5-transcribe`. Select `muse-voice-transcribe-1.0` or `MAI-Transcribe-2` with `--model` when using Meta or Microsoft. Check whether an output file already exists before using `-o`: the CLI replaces it.
