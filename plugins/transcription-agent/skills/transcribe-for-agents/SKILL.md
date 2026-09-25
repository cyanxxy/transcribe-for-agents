---
name: transcribe-for-agents
description: Transcribe a local MP3, WAV, M4A, FLAC, or OGG recording with Transcription Agent; produce a timestamped, speaker-labeled TXT, SRT, or JSON file. Use when the user asks for audio transcription, subtitles, diarization, or a transcript export.
---

# Transcribe audio

Use the Go `transcriber-cli` from [Transcription Agent](https://github.com/cyanxxy/transcription-agent-go). Use the absolute executable path in `TRANSCRIBER_CLI` if set, otherwise find `transcriber-cli` on `PATH`, otherwise use `$HOME/.local/bin/transcriber-cli` (the guided install location, which may not be on `PATH`). Call it by that absolute path in every command below. This skill does not contain a transcription engine or require Python.

1. Find the local audio file. Ask for its path only if it cannot be found from the user's message or workspace.
2. Choose `txt` by default, `srt` for subtitles, or `json` for structured segments and metadata. Save beside the audio unless the user names another destination. Check whether the output exists before running: the CLI replaces a file named with `-o`, so use a different path unless the user wants it replaced.
3. If the CLI is missing, direct the user to the [one-command installer](https://github.com/cyanxxy/transcribe-for-agents#one-command-setup). It installs the engine and skill, then prompts for a key in their terminal. Check credentials with `transcriber-cli auth status` (or `auth status gemini`, `meta`, or `microsoft`, which exits nonzero when that provider is not configured). To save a key later, tell the user to run `transcriber-cli auth set gemini` (or `meta` or `microsoft`) in their own terminal. Never ask the user to paste a key into chat or put it in command arguments.
4. Run with absolute paths, for example:

   ```bash
   transcriber-cli -i /absolute/path/to/meeting.m4a -o /absolute/path/to/meeting.srt -format srt
   ```

   - **Allow for a long run.** Transcription can take several minutes for long recordings, and the engine stops itself after 30 minutes. Give the command the longest timeout your shell tool allows (for example 600000 ms in Claude Code), or run it in the background and wait for the process to exit. The output file is written only when transcription finishes. If the command times out or moves to the background, keep waiting for that process and then check the output. Do not start a second run, which costs the user twice and can overwrite the file.
   - **Network access is required.** The CLI sends the audio to the provider's API and reads the saved key from the user's home directory. If commands run in a sandbox without network access (Codex does by default), request approval to run this command with network access or outside the sandbox. Connection or DNS errors from a sandboxed run mean network access was blocked; they do not mean the key is missing.

5. Only these three models are supported. Pick one with `-model`; the wrapper rejects any other model:
   - `gemini-3.5-transcribe` (default): Google Gemini. Needs the `gemini` key.
   - `muse-voice-transcribe-1.0`: Meta Muse Voice Transcribe. Needs the `meta` key.
   - `MAI-Transcribe-2`: Microsoft MAI-Transcribe-2 on Azure Speech. Needs the `microsoft` key and endpoint.

   Use Meta or Microsoft only when the user asks for it or when it is the only configured provider (`transcriber-cli auth status`).
6. Do not pass `-topic`, `-speakers`, `-terms`, `-keywords`, `-language-hints`, `-instructions`, `-expected-format`, or `-judge-model`. These three speech models ignore them, so do not promise that names, terms, or context will change the result.
7. After success, check that the output file exists and is nonempty. Report its path, format, model, and any limitations visible in the result. Do not invent a transcript if the command fails.

The CLI also accepts provider credentials from environment variables (`GEMINI_API_KEY`, `META_API_KEY`, `AZURE_SPEECH_KEY`, `AZURE_SPEECH_ENDPOINT`), which take precedence over saved keys. `ffmpeg` and `ffprobe` must be on `PATH`.
