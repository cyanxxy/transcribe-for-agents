---
name: transcribe
description: Transcribe a local MP3, WAV, M4A, FLAC, or OGG recording with Transcription Agent; produce a timestamped, speaker-labeled TXT, SRT, or JSON file. Use when the user asks for audio transcription, subtitles, diarization, or a transcript export.
---

# Transcribe audio

Use the script at `../../scripts/transcribe.py` relative to this `SKILL.md`. Run it with `python3` and absolute input and output paths. The script runs the project's `transcriber-cli` binary; it does not implement transcription itself.

1. Check that the audio file exists. Ask for its path only if it cannot be found from the user's message or workspace.
2. Choose `txt` by default, `srt` for subtitles, or `json` when the user needs structured segments or metadata. Save beside the audio unless the user names another destination. Choose a distinct output path if a transcript file already exists; use `--overwrite` only when the user wants it replaced.
3. Run, for example:

   ```bash
   python3 /absolute/path/to/plugin/scripts/transcribe.py --input /absolute/path/to/meeting.m4a --output /absolute/path/to/meeting.srt --format srt
   ```

4. Use `--model muse-voice-transcribe-1.0` for Meta or `--model MAI-Transcribe-2` for Microsoft only when requested or when the available credentials make that choice clear. Otherwise use the default `gemini-3.5-transcribe`.
5. Credentials can be set interactively with `python3 ../../scripts/setup.py --provider gemini` (or `meta` or `microsoft`) relative to this skill. The launcher also accepts `GEMINI_API_KEY`, `META_API_KEY`, or both `AZURE_SPEECH_KEY` and `AZURE_SPEECH_ENDPOINT` from the process environment, which take precedence over saved values. Never put secret values in command arguments, transcript files, or chat output. If credentials are missing, tell the user to run setup themselves; do not ask them to paste a key into chat.
6. `--topic`, `--speakers`, `--terms`, `--language-hints`, and `--expected-format` apply to the general-purpose Gemini pipeline, not the direct speech models. Do not promise those hints will influence the default direct model.
7. After the command succeeds, check that the output file exists and is nonempty. Report the file path, selected format and model, and any limitations visible in the result. Do not invent a transcript if the command fails.

The launcher accepts `--help` for its full option list. If it cannot find the CLI, build it from the Transcription Agent source repository and put it on `PATH`, or set `TRANSCRIBER_CLI` to the executable path. `ffmpeg` and `ffprobe` are also required on `PATH`.
