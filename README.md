<div align="center">

# 🎙️ Transcribe for Agents

**Hand Claude Code or Codex a recording. Get back a timestamped, speaker-labeled transcript.**

[![CI](https://github.com/cyanxxy/transcribe-for-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/cyanxxy/transcribe-for-agents/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Agents](https://img.shields.io/badge/agents-Claude%20Code%20%7C%20Codex-8A2BE2)

[Quick start](#-quick-start) · [Models](#-supported-models) · [Usage](#-usage) · [Credentials](#-credentials) · [Other install options](#-other-install-options) · [Development](#-development)

</div>

---

A skill for coding agents, powered by the Go CLI from [Transcription Agent](https://github.com/cyanxxy/transcription-agent-go). Ask your agent to transcribe a meeting, interview, or podcast and it produces a file next to the audio.

| | |
| --- | --- |
| **Input** | MP3 · WAV · M4A · FLAC · OGG |
| **Output** | `txt` transcript · `srt` subtitles · `json` segments and metadata |
| **Features** | Speaker labels · timestamps · three speech providers |
| **Requirements** | `git`, `curl`, Go, FFmpeg. No Python or Node.js. |

## ⚡ Quick start

Run this in your own terminal on macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/cyanxxy/transcribe-for-agents/main/install.sh | bash
```

Then start a new agent session and ask:

> Transcribe `~/Recordings/standup.m4a` and save subtitles.

### What the installer does

1. **Checks prerequisites.** If Go or FFmpeg is missing and Homebrew is available, it offers to install them. Otherwise it tells you what to install.
2. **Installs the skill** for both Claude Code and Codex.
3. **Builds the CLI** from the pinned `v1.1.0` engine release (verified against its commit hash) into `~/.local/bin/transcriber-cli`.
4. **Asks for your API key** in the terminal, without echoing it. If a key is already saved, it says so and skips the prompt.
5. **Warns you** if `~/.local/bin` is not on your `PATH`.

<details>
<summary><b>Installer options</b></summary>

<br>

Prefer to read it first? [Read install.sh](install.sh), then clone this repository and run `bash install.sh` with any of these options:

| Option | Effect |
| --- | --- |
| `--agent claude-code` \| `codex` \| `both` | Choose which agent gets the skill (default: `both`). |
| `--provider gemini` \| `meta` \| `microsoft` | Choose which key to set up (default: `gemini`). |
| `--skip-auth` | Skip the key prompt and add a key later. You need a key before the first transcription. |

To pass options through the one-line install, use `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/cyanxxy/transcribe-for-agents/main/install.sh | bash -s -- --agent codex --provider meta
```

</details>

### Upgrading

Run the same command again. The installer replaces the skill and CLI it installed earlier and moves the old copies to `~/.local/share/transcribe-for-agents/backups/`. It never overwrites a `transcriber-cli` or `transcribe-for-agents` skill that it did not install.

## 🧠 Supported models

Three direct speech models are supported. Pick one with `-model`; the CLI rejects any other model.

| Model | Provider | Credentials |
| --- | --- | --- |
| `gemini-3.5-transcribe` **(default)** | [Google Gemini 3.5 Transcribe](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-transcribe) | `gemini` key |
| `muse-voice-transcribe-1.0` | [Meta Muse Voice Transcribe](https://dev.meta.ai/models/muse-voice-transcribe/) | `meta` key |
| `MAI-Transcribe-2` | [Microsoft MAI-Transcribe-2](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/mai-transcribe) on Azure Speech | `microsoft` key and resource endpoint |

Every input is converted to mono WAV with FFmpeg before upload, so any supported input format works with every model.

## 🚀 Usage

### With your agent

Ask in plain language, for example *"transcribe this interview as JSON"*. In Claude Code you can also call the skill directly:

```text
/transcribe-for-agents /absolute/path/to/meeting.m4a
```

If you installed it as a plugin, the command is `/transcription-agent:transcribe-for-agents`.

The agent saves the output next to the audio unless you name another path, checks that the file was written, and reports the path, format, and model it used.

### From the terminal

```bash
# Subtitles with the default Gemini model
transcriber-cli -i ~/Recordings/meeting.m4a -o ~/Recordings/meeting.srt -format srt

# Structured JSON with Meta Muse Voice Transcribe
transcriber-cli -model muse-voice-transcribe-1.0 -i interview.wav -o interview.json -format json

# Plain text with Microsoft MAI-Transcribe-2, printed to stdout
transcriber-cli -model MAI-Transcribe-2 -i podcast.mp3
```

> [!WARNING]
> `-o` replaces an existing file. Choose an unused path unless you mean to overwrite it.

## 🔐 Credentials

Keys are stored in owner-only files (mode `600`) in `~/.config/transcribe-for-agents/`, or `$XDG_CONFIG_HOME/transcribe-for-agents/` if that is set. They never appear in command arguments or in the agent chat.

```bash
transcriber-cli auth set gemini       # prompt for a key (Microsoft also asks for the endpoint)
transcriber-cli auth status           # show every provider
transcriber-cli auth status gemini    # exit code 1 if not configured
transcriber-cli auth remove gemini    # delete the saved key
```

Environment variables override saved keys:

| Provider | Variables |
| --- | --- |
| Gemini | `GEMINI_API_KEY` |
| Meta | `META_API_KEY` |
| Microsoft | `AZURE_SPEECH_KEY` and `AZURE_SPEECH_ENDPOINT` (for example `https://your-resource.cognitiveservices.azure.com`) |

For each run, the CLI passes on only the credentials for the selected model's provider. Other providers' keys are removed from the engine's environment, even if you set them in your shell.

<details>
<summary><b>Advanced environment variables</b></summary>

<br>

| Variable | Purpose |
| --- | --- |
| `TRANSCRIBER_CLI` | Absolute path to the wrapper, if it is not on `PATH` or in `~/.local/bin`. The skill checks this first. |
| `TRANSCRIBER_ENGINE_BIN` | Run a different engine binary instead of the installed one. |
| `XDG_CONFIG_HOME` / `XDG_DATA_HOME` | Change where keys and the engine are stored. |

</details>

## 📦 Other install options

The skill and plugins below **do not include the transcription engine or a key**. Use them only if `transcriber-cli` is already installed and configured. Use one install method per agent to avoid duplicate skills.

<details>
<summary><b>Skills CLI</b></summary>

<br>

With the [Skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add cyanxxy/transcribe-for-agents --skill transcribe-for-agents --agent claude-code --global
npx skills add cyanxxy/transcribe-for-agents --skill transcribe-for-agents --agent codex --global
```

</details>

<details>
<summary><b>Claude Code plugin</b></summary>

<br>

```bash
claude plugin marketplace add cyanxxy/transcribe-for-agents
claude plugin install transcription-agent@transcription-agent-tools
```

</details>

<details>
<summary><b>Codex plugin</b></summary>

<br>

```bash
codex plugin marketplace add cyanxxy/transcribe-for-agents
codex plugin add transcription-agent@transcription-agent-tools
```

</details>

## 🛠️ Troubleshooting

| Symptom | Fix |
| --- | --- |
| `transcriber-cli: command not found` | Add `~/.local/bin` to your `PATH`, or call `~/.local/bin/transcriber-cli` directly. |
| `transcription engine is missing` | Run the installer again. |
| `unsupported model: …` | Use one of the three [supported models](#-supported-models). |
| `… is not a transcribe-for-agents wrapper` or `… skill` | Another tool already uses that path. Move it, then run the installer again. |
| `microsoft: incomplete` | Microsoft needs both a key and an endpoint. Run `transcriber-cli auth set microsoft`. |
| The agent doesn't see the skill | Start a new agent session after installing. |

FFmpeg (`ffmpeg` and `ffprobe`) must stay on your `PATH` when the agent runs.

## 🧑‍💻 Development

```bash
claude --plugin-dir ./plugins/transcription-agent   # load the plugin from this checkout
npx skills add . --list                             # check that the skill is discovered
bash tests/install_test.sh                          # test the installer and wrapper
```

The tests replace `go`, `git`, `ffmpeg`, and `ffprobe` with fakes, so they need no network or toolchain. CI runs them on Linux and macOS along with ShellCheck and JSON manifest checks.

<details>
<summary><b>Repository layout</b></summary>

<br>

```text
install.sh                          One-command installer
scripts/transcriber-cli             Wrapper: loads credentials, runs the engine
plugins/transcription-agent/
  skills/transcribe-for-agents/     The shared skill (SKILL.md)
  .claude-plugin/plugin.json        Claude Code plugin manifest
  .codex-plugin/plugin.json         Codex plugin manifest
.claude-plugin/marketplace.json     Claude Code marketplace
.agents/plugins/marketplace.json    Codex marketplace
tests/install_test.sh               Hermetic installer and wrapper tests
```

</details>

## 📄 License

[Apache 2.0](LICENSE)
