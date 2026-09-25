# Transcribe for Agents

Give Claude Code or Codex a local recording and get a timestamped, speaker-labeled transcript or subtitles. The shared [transcribe skill](plugins/transcription-agent/skills/transcribe/SKILL.md) uses the Go CLI from [Transcription Agent](https://github.com/cyanxxy/transcription-agent-go) and supports MP3, WAV, M4A, FLAC, and OGG input with TXT, SRT, or JSON output.

## One-command setup

Run this in your own terminal on macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/cyanxxy/transcribe-for-agents/main/install.sh | bash
```

The installer copies the skill to both Claude Code and Codex, builds the Go CLI from the pinned `v1.1.0` release, and prompts privately for a Gemini API key. If Go or FFmpeg is missing on a Mac with Homebrew, it offers to install them. On other systems, it names missing prerequisites. You need `git` and `curl`; no Python or Node.js runtime is required. The key is the one setup step that cannot be skipped for a cloud speech provider.

Prefer to inspect the installer first? [Read install.sh](install.sh), then clone this repository and run `bash install.sh`. Use `--agent claude-code` or `--agent codex` to install for only one agent. Use `--provider meta` or `--provider microsoft` for another speech provider, or `--skip-auth` to configure a key later.

The installer stores the key in an owner-only file under `~/.config/transcribe-for-agents/` (or `$XDG_CONFIG_HOME/transcribe-for-agents/`). The installed `~/.local/bin/transcriber-cli` wrapper reads it and starts the Go CLI. Environment variables `GEMINI_API_KEY`, `META_API_KEY`, `AZURE_SPEECH_KEY`, and `AZURE_SPEECH_ENDPOINT` take precedence. To change or remove a key later, run:

```bash
~/.local/bin/transcriber-cli auth set gemini
~/.local/bin/transcriber-cli auth status
~/.local/bin/transcriber-cli auth remove gemini
```

Start a new agent session after installation. Ask it to transcribe a recording, or invoke `/transcribe /absolute/path/to/meeting.m4a` in Claude Code. The CLI can also run directly:

```bash
~/.local/bin/transcriber-cli -i /absolute/path/to/meeting.m4a -o /absolute/path/to/meeting.srt -format srt
```

The default model is `gemini-3.5-transcribe`. Choose `muse-voice-transcribe-1.0` for Meta or `MAI-Transcribe-2` for Microsoft with `--model`. The CLI replaces an existing output file named with `-o`, so choose an unused path unless you intend to overwrite it.

## Install only the skill

If you already have `transcriber-cli` and the provider key configured, use the [Skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add cyanxxy/transcribe-for-agents --skill transcribe --agent claude-code --global
npx skills add cyanxxy/transcribe-for-agents --skill transcribe --agent codex --global
```

You can also install the native plugin from this repository's marketplaces:

```bash
# Claude Code
claude plugin marketplace add cyanxxy/transcribe-for-agents
claude plugin install transcription-agent@transcription-agent-tools

# Codex
codex plugin marketplace add cyanxxy/transcribe-for-agents
codex plugin add transcription-agent@transcription-agent-tools
```

Choose one skill installation method per agent to avoid duplicate `transcribe` skills. The skill and plugin do not include the transcription engine or a provider key; use the installer above for the guided setup.

## Local development

Claude Code can load the plugin directly with `claude --plugin-dir ./plugins/transcription-agent`. Run `npx skills add . --list` from this checkout to verify skill discovery. The [Claude marketplace](.claude-plugin/marketplace.json) and [Codex marketplace](.agents/plugins/marketplace.json) package the same skill.
