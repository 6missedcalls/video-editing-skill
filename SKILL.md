# Video Editing

Edit videos using natural language instructions. Supports trimming, jump cuts (silence removal), captions with multiple styles, text overlays, and speed changes — all powered by ffmpeg and Whisper.

## Usage

Give a video file path and describe what you want done:

```
Edit my video at ~/video.mp4 — remove silence, add Hormozi-style captions, and speed it up 1.25x
```

```
Trim ~/interview.mp4 from 00:02:00 to 00:15:00 and add standard captions
```

```
Add a "Subscribe!" text overlay at the 1 minute mark in ~/video.mp4
```

## Capabilities

### Trimming
Cut video to specific start/end timestamps or duration.
```bash
scripts/trim.sh video.mp4 --start 00:01:30 --end 00:05:00
```

### Jump Cuts (Silence Removal)
Auto-detect and remove silent/dead-air sections. Configurable threshold, minimum silence duration, and padding.
```bash
scripts/jumpcut.sh video.mp4 --threshold -30 --duration 0.5 --padding 0.1
```

### Captions
Transcribe audio with Whisper, then burn subtitles into video. Three caption styles:

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
Add text at specific positions and timestamps. Supports 7 positions: center, top, bottom, top-left, top-right, bottom-left, bottom-right.
```bash
scripts/overlay-text.sh video.mp4 --text "Subscribe!" --start 00:01:00 --end 00:01:05 --position bottom-right
```

### Speed Changes
Adjust playback speed (audio pitch-corrected via atempo).
```bash
# Via edit.sh orchestrator
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

## Requirements

- **ffmpeg** — video processing (must be installed)
- **whisper** — audio transcription for captions (openai-whisper CLI)

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/edit.sh` | Main orchestrator — chains all operations |
| `scripts/transcribe.sh` | Whisper transcription → SRT file |
| `scripts/caption.sh` | Burn SRT captions into video with style |
| `scripts/trim.sh` | Trim by timestamps |
| `scripts/jumpcut.sh` | Auto-remove silence via silencedetect |
| `scripts/overlay-text.sh` | Add positioned text overlays |

## Agent Instructions

When the user asks to edit a video:

1. **Parse the request** — identify which operations are needed (trim, jumpcut, caption, overlay, speed)
2. **Use edit.sh for multi-operation edits** — it chains operations in the correct order
3. **Use individual scripts for single operations** — faster, simpler output
4. **For captions**: if the user has an existing SRT, use `--caption-srt`; otherwise transcription runs automatically
5. **Default caption style**: use "standard" unless the user specifies a style
6. **Default whisper model**: use "base" for speed; suggest "medium" or "large" for accuracy on long/noisy videos
7. **Output**: always tell the user the output file path and duration
