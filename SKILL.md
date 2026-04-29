---
name: video-editing
description: "Edit videos using natural language — trim, jump-cut silence, burn captions (hormozi/standard/minimal), add text overlays, and change speed via ffmpeg and Whisper. Use when the user asks to edit, trim, cut, caption, subtitle, overlay text on, or change speed of a video, or mentions ffmpeg, Whisper, or video processing."
---

# Video Editing

Edit videos using natural language instructions. Supports trimming, jump cuts (silence removal), captions with multiple styles, text overlays, and speed changes — all powered by ffmpeg and Whisper.

## Prerequisites

Before running any operation, verify dependencies are available:

```bash
command -v ffmpeg >/dev/null || echo "ERROR: ffmpeg not installed — install via: brew install ffmpeg (macOS) or apt install ffmpeg (Linux)"
command -v whisper >/dev/null || echo "WARNING: whisper not installed — captions require: pip install openai-whisper"
```

## Capabilities

### Trimming
```bash
scripts/trim.sh video.mp4 --start 00:01:30 --end 00:05:00
```

### Jump Cuts (Silence Removal)
```bash
scripts/jumpcut.sh video.mp4 --threshold -30 --duration 0.5 --padding 0.1
```

### Captions

| Style | Description |
|-------|-------------|
| **hormozi** | Bold, centered, large — Alex Hormozi word-by-word impact style |
| **standard** | Traditional bottom subtitles with semi-transparent background |
| **minimal** | Small lower-third captions, clean and unobtrusive |

```bash
scripts/transcribe.sh video.mp4 --model base --language en
scripts/caption.sh video.mp4 video.srt --style hormozi
```

### Text Overlays
Positions: center, top, bottom, top-left, top-right, bottom-left, bottom-right.
```bash
scripts/overlay-text.sh video.mp4 --text "Subscribe!" --start 00:01:00 --end 00:01:05 --position bottom-right
```

### Speed Changes
```bash
scripts/edit.sh video.mp4 --speed 1.5
```

### Full Pipeline (Orchestrator)
Chain multiple operations in a single command:
```bash
scripts/edit.sh video.mp4 \
  --trim-start 00:00:10 --trim-end 00:10:00 \
  --jumpcut \
  --caption --caption-style hormozi \
  --speed 1.25 \
  --overlay-text "Like & Subscribe" --overlay-start 00:01:00 \
  --output final.mp4
```

Pipeline order: trim → jump cut → speed → caption → overlay

## Agent Instructions

1. **Check prerequisites** — verify `ffmpeg` is installed; verify `whisper` is installed if captions are requested. If missing, provide install instructions and stop.
2. **Parse the request** — identify which operations are needed (trim, jumpcut, caption, overlay, speed).
3. **Use `scripts/edit.sh` for multi-operation edits** — it chains operations in the correct order.
4. **Use individual scripts for single operations** — faster, simpler output.
5. **For captions**: if the user has an existing SRT, use `--caption-srt`; otherwise transcription runs automatically.
6. **Default caption style**: use "standard" unless the user specifies a style.
7. **Default whisper model**: use "base" for speed; suggest "medium" or "large" for accuracy on long/noisy videos.
8. **Verify output** — confirm the output file exists and report its path and duration to the user. If a script fails, check stderr for common issues (missing codec, unsupported format, out-of-range timestamps).
