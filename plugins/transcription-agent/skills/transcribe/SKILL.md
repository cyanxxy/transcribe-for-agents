---
name: transcribe
description: Transcribe a local MP3, WAV, M4A, FLAC, or OGG recording with Transcription Agent; produce a timestamped, speaker-labeled TXT, SRT, or JSON file. Use when the user asks for audio transcription, subtitles, diarization, or a transcript export.
---

# Transcribe audio

Use the Go `transcriber-cli` from [Transcription Agent](https://github.com/cyanxxy/transcription-agent-go). Find it on `PATH`, or use the absolute executable path in `TRANSCRIBER_CLI` if set. This plugin does not contain a transcription engine or require Python.

1. Find the local audio file. Ask for its path only if it cannot be found from the user's message or workspace.
2. Choose `txt` by default, `srt` for subtitles, or `json` for structured segments and metadata. Save beside the audio unless the user names another destination. Check whether the output exists before running: the CLI replaces a file named with `-o`, so use a different path unless the user wants it replaced.
3. Check credential status with `transcriber-cli auth status` if needed. To save a key, tell the user to run `transcriber-cli auth set gemini` (or `meta` or `microsoft`) in their own terminal. The CLI prompts without echoing the key. Never ask the user to paste a key into chat or put it in command arguments.
4. Run with absolute paths, for example:

   ```bash
   transcriber-cli -i /absolute/path/to/meeting.m4a -o /absolute/path/to/meeting.srt -format srt
   ```

5. Use `--model muse-voice-transcribe-1.0` for Meta or `--model MAI-Transcribe-2` for Microsoft only when requested or when configured credentials make the choice clear. Otherwise use the default `gemini-3.5-transcribe`.
6. `--topic`, `--speakers`, `--terms`, `--language-hints`, and `--expected-format` apply to the general-purpose Gemini pipeline, not the direct speech models. Do not promise those hints will influence the default direct model.
7. After success, check that the output file exists and is nonempty. Report its path, format, model, and any limitations visible in the result. Do not invent a transcript if the command fails.

The CLI also accepts provider credentials from environment variables, which take precedence over saved keys. `ffmpeg` and `ffprobe` must be on `PATH`.
