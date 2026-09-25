<div align="center">

<img src="plugins/transcription-agent/assets/logo.png" alt="" width="96" height="96">

# Transcription Agent Plugin

**Coding agents can't hear. This gives them ears.**

Hand Claude Code, Codex, or any Agent Skills agent a recording and get back a timestamped, speaker-labeled transcript, subtitles, or JSON.

This repository is the plugin package. It currently contains the shared transcription skill, plugin manifests, and installer. The package can also host an MCP server when that integration is ready.

[![CI](https://github.com/cyanxxy/transcription-agent-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/cyanxxy/transcription-agent-plugin/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Agents](https://img.shields.io/badge/agents-Claude%20Code%20%7C%20Codex%20%7C%20Agent%20Skills-6D28D9)

[Why](#-the-problem) · [Quick start](#-quick-start) · [Works with](#-works-with) · [Models](#-supported-models) · [Usage](#-usage) · [Credentials](#-credentials) · [Troubleshooting](#%EF%B8%8F-troubleshooting)

</div>

---

## 🤔 The problem

Recordings are everywhere in real work: standups, customer calls, interviews, podcasts, voice memos. Coding agents can read your code, your screenshots, and your PDFs, but not your audio.

- **Claude Code can't open audio files.** Its Read tool handles text, images, PDFs, and notebooks, and it has [no built-in audio tool](https://code.claude.com/docs/en/tools-reference). `/voice` dictates your prompt; it doesn't transcribe a file on disk.
- **Codex can't either.** You can attach [files, folders, and images](https://learn.chatgpt.com/docs/features), and its voice mode is for talking to Codex, not for turning a recording into text.
- **So agents improvise.** Asked for a transcript, an agent will typically try to install a local speech model: a Python environment, gigabytes of model weights, slow runs on a laptop CPU, and no speaker labels without yet another tool. Or it gives up and asks you to do it elsewhere.

**Transcription Agent Plugin** closes that gap with a skill and one command. The agent calls `transcriber-cli`, which sends the audio to one of today's dedicated speech-to-text models and writes the result next to the recording:

- 🗣️ **Speaker labels and timestamps** on every segment
- 🎞️ **TXT, SRT, or JSON**, ready for notes, subtitles, or code
- 📼 **Long recordings handled for you.** FFmpeg converts any MP3, WAV, M4A, FLAC, or OGG and splits long audio into chunks that fit each provider's limits
- 🔐 **Keys stay out of the chat.** They're saved on your machine and never passed as command arguments
- 🪶 **No Python or Node.js runtime.** A single Go binary plus FFmpeg

## ⚡ Quick start

**Claude Code and Codex.** Run this in your own terminal on macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/cyanxxy/transcription-agent-plugin/main/install.sh | bash
```

**Any other Agent Skills agent** (Cursor, GitHub Copilot, OpenCode, and [more](#-works-with)). Install the CLI and key, then add the skill with the [Skills CLI](https://github.com/vercel-labs/skills):

```bash
curl -fsSL https://raw.githubusercontent.com/cyanxxy/transcription-agent-plugin/main/install.sh | bash -s -- --agent none
npx skills add cyanxxy/transcription-agent-plugin --skill transcribe-for-agents -g -a cursor
```

Then start a new agent session and ask:

> Transcribe `~/Recordings/standup.m4a` and save subtitles.

### What the installer does

1. **Checks prerequisites.** If Go or FFmpeg is missing and Homebrew is available, it offers to install them. Otherwise it tells you what to install.
2. **Installs the skill** for Claude Code (`~/.claude/skills`) and Codex (`~/.agents/skills`). If the `transcription-agent` plugin is already enabled for an agent, it skips that agent so the skill doesn't load twice. It also backs up and removes an older copy in Codex's deprecated `~/.codex/skills` folder. With `--agent none` it installs no skill.
3. **Builds the CLI** from the pinned `v1.1.0` engine release (verified against its commit hash) into `~/.local/bin/transcriber-cli`.
4. **Asks for your API key** in the terminal, without echoing it. If a key is already saved, it says so and skips the prompt.
5. **Warns you** if `~/.local/bin` is not on your `PATH`.

<details>
<summary><b>Installer options</b></summary>

<br>

Prefer to read it first? [Read install.sh](install.sh), then clone this repository and run `bash install.sh` with any of these options:

| Option | Effect |
| --- | --- |
| `--agent claude-code` \| `codex` \| `both` \| `none` | Choose which agent gets the skill (default: `both`). `none` installs only the CLI and key. |
| `--provider gemini` \| `meta` \| `microsoft` | Choose which key to set up (default: `gemini`). |
| `--skip-auth` | Skip the key prompt and add a key later. You need a key before the first transcription. |

To pass options through the one-line install, use `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/cyanxxy/transcription-agent-plugin/main/install.sh | bash -s -- --agent codex --provider meta
```

</details>

### Upgrading

Run the same command again. The installer replaces the skill and CLI it installed earlier and moves the old copies to `~/.local/share/transcribe-for-agents/backups/`. It never overwrites a `transcriber-cli` or `transcribe-for-agents` skill that it did not install.

## 🤝 Works with

The skill follows the open [Agent Skills](https://agentskills.io/specification) format, so any agent that supports it can use it. Every agent needs `transcriber-cli` installed (the installer above) and a way to run shell commands with network access.

| Agent | Install the skill with | Status |
| --- | --- | --- |
| **Claude Code** | The installer, or the [Claude Code plugin](#-other-install-options) | ✅ Tested |
| **Codex** (CLI and app) | The installer, or the [Codex plugin](#-other-install-options) | ✅ Tested |
| **Cursor** | `npx skills add … -g -a cursor` | Agent Skills compatible |
| **GitHub Copilot** | `npx skills add … -g -a github-copilot` | Agent Skills compatible |
| **OpenCode** | `npx skills add … -g -a opencode` | Agent Skills compatible |
| **Amp** | `npx skills add … -g -a amp` | Agent Skills compatible |
| **Goose** | `npx skills add … -g -a goose` | Agent Skills compatible |
| **Windsurf** | `npx skills add … -g -a windsurf` | Agent Skills compatible |
| **Gemini CLI** | `npx skills add … -g -a gemini-cli` | Agent Skills compatible |
| **Antigravity CLI** | `npx skills add … -g -a antigravity-cli` | Agent Skills compatible |

`…` stands for `cyanxxy/transcription-agent-plugin --skill transcribe-for-agents`. See the [Skills CLI](https://github.com/vercel-labs/skills) for every supported agent.

> [!NOTE]
> Cloud agent sessions (Claude Code on the web, Codex cloud) don't have your local CLI or keys, so the skill works only where the agent runs on your machine.

## 🧠 Supported models

Three dedicated speech-to-text models are supported. Pick one with `-model`; the CLI rejects any other model.

| | Gemini 3.5 Transcribe **(default)** | Meta Muse Voice Transcribe | Microsoft MAI-Transcribe-2 |
| --- | --- | --- | --- |
| **Model ID** | `gemini-3.5-transcribe` | `muse-voice-transcribe-1.0` | `MAI-Transcribe-2` |
| **Languages** | 85+ | 25+ | 60 |
| **Speakers** | Up to 8 (3+ is experimental) | 20+ (non-overlapping speech) | Speaker diarization |
| **Credentials** | `gemini` key | `meta` key | `microsoft` key and Azure Speech endpoint |
| **Docs** | [Google AI](https://ai.google.dev/gemini-api/docs/transcribe) | [Meta](https://dev.meta.ai/models/muse-voice-transcribe/) | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/mai-transcribe) (public preview) |

Figures come from each provider's documentation as of September 2026. Every input is converted to mono WAV with FFmpeg and split into chunks before upload, so any supported format and length works with every model. The CLI accepts files up to 200 MiB and stops a run after 30 minutes.

## 🚀 Usage

### With your agent

Ask in plain language, for example *"transcribe this interview as JSON"*. In Claude Code you can also call the skill directly:

```text
/transcribe-for-agents /absolute/path/to/meeting.m4a
```

If you installed it as a plugin, the command is `/transcription-agent:transcribe-for-agents`.

The agent saves the output next to the audio unless you name another path, checks that the file was written, and reports the path, format, and model it used. Long recordings can take several minutes; the skill tells the agent to wait for the run to finish rather than start another one.

### Codex: allow network access

Codex runs commands in a sandbox with network access off by default, and the CLI needs the network to reach the speech provider. When Codex asks to run `transcriber-cli` with network access, approve it. To allow network access for all sandboxed commands instead, add this to `~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
network_access = true
```

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
<summary><b>Skills CLI (any Agent Skills agent)</b></summary>

<br>

With the [Skills CLI](https://github.com/vercel-labs/skills), replacing `cursor` with [your agent](#-works-with):

```bash
npx skills add cyanxxy/transcription-agent-plugin --skill transcribe-for-agents -g -a cursor
```

</details>

<details>
<summary><b>Claude Code plugin</b></summary>

<br>

```bash
claude plugin marketplace add cyanxxy/transcription-agent-plugin
claude plugin install transcription-agent@transcription-agent-tools
```

</details>

<details>
<summary><b>Codex plugin</b></summary>

<br>

```bash
codex plugin marketplace add cyanxxy/transcription-agent-plugin
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
| The agent lists the skill twice | Keep one install method per agent: the plugin or the installer's standalone copy. Run the installer again after enabling the plugin to remove the copy. |
| Connection or DNS errors in Codex | Network access is blocked by the sandbox. See [Codex: allow network access](#codex-allow-network-access). |

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
    agents/openai.yaml              Codex skill picker name, icon, and prompt
  assets/                           Plugin logo and icon
  .claude-plugin/plugin.json        Claude Code plugin manifest
  .codex-plugin/plugin.json         Codex plugin manifest
.claude-plugin/marketplace.json     Claude Code marketplace
.agents/plugins/marketplace.json    Codex marketplace
tests/install_test.sh               Hermetic installer and wrapper tests
```

</details>

## 📄 License

[Apache 2.0](LICENSE)
