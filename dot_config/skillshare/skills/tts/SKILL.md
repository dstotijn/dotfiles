---
name: tts
description: Create a spoken-audio WAV file from text on macOS. Use this skill whenever the user asks for text-to-speech, voice narration, spoken audio, an audio reading, or a `.wav` file generated from text. Do not use it for transcribing existing audio, editing audio, cloning a voice, or producing music.
---

# Text to speech

Create a valid PCM WAV file from the user's text with the bundled
`scripts/tts.sh` script. The script uses macOS `say`, requires no API key, and
keeps the text local.

## Workflow

1. Use the text exactly as provided unless the user asks you to edit it.
2. Choose the requested output path. If none is given, write `speech.wav` in
   the current working directory.
3. Pass long, multiline, or shell-sensitive text through standard input or an
   input file. Avoid interpolating it into a shell command.
4. Use the system voice and rate unless the user asks for specific settings.
5. Verify the result with `file` and `afinfo` before returning it.
6. Give the user a clickable link to the WAV file and state the voice or rate
   only when you changed it from the system default.

## Create the WAV file

Resolve the skill directory from the loaded skill path, then run:

```bash
printf '%s' "$text" | "$SKILL_DIR/scripts/tts.sh" --output /absolute/path/speech.wav
```

For text already stored in a file:

```bash
"$SKILL_DIR/scripts/tts.sh" \
  --input-file /absolute/path/input.txt \
  --output /absolute/path/speech.wav
```

Optional settings:

```bash
"$SKILL_DIR/scripts/tts.sh" \
  --voice Samantha \
  --rate 180 \
  --output /absolute/path/speech.wav \
  -- "Text to speak"
```

Run `say -v '?'` to list installed voices when the user asks to choose one.
Use an exact installed voice name. Do not download voices or other tools unless
the user asks you to.

The script refuses to overwrite an existing file. Use `--force` only when the
user has explicitly asked to replace it.

## Verify the output

Run both checks:

```bash
file /absolute/path/speech.wav
afinfo /absolute/path/speech.wav
```

Confirm that `file` identifies RIFF/WAVE audio and that `afinfo` reports a
positive duration. If synthesis or verification fails, report the error and do
not present the file as complete.

