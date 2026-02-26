<div align="center">

# video-editing-skill

**Edit videos with natural language — trim, jump cut, caption, overlay, and speed up — all from your terminal.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](scripts/)
[![FFmpeg](https://img.shields.io/badge/FFmpeg-Powered-007808?logo=ffmpeg&logoColor=white)](#requirements)
[![Whisper](https://img.shields.io/badge/Whisper-OpenAI-412991?logo=openai&logoColor=white)](#requirements)
[![Scripts: 6](https://img.shields.io/badge/Scripts-6-orange)](#scripts-reference)
[![Made for: Claude Code](https://img.shields.io/badge/Made_for-Claude_Code-blueviolet)](https://claude.ai/claude-code)

---

**Trim clips** &bull; **Remove silence** &bull; **Burn captions** &bull; **Add text overlays** &bull; **Adjust speed** &bull; **Chain it all**

Zero runtime dependencies beyond FFmpeg and Whisper. Pure Bash, composable, pipeline-ready.

[Requirements](#requirements) &bull; [Quick Start](#quick-start) &bull; [Capabilities](#capabilities) &bull; [Pipeline](#full-pipeline) &bull; [Scripts](#scripts-reference) &bull; [License](#license)

</div>

---

## Why This Skill?

AI agents are great at writing code — but when you ask them to edit a video, they reach for bloated Python libraries, spin up runtimes, and still can't chain operations together.

- **Pure Bash + FFmpeg** — no Python runtimes, no package managers, no build steps
- **Composable pipeline** — chain trim, jump cut, speed, caption, and overlay in a single command
- **3 caption styles** — Hormozi, standard, and minimal — burned directly into the video
- **Smart silence removal** — auto-detects dead air with configurable thresholds
- **Whisper transcription** — generates SRT files locally, no API calls, no cloud dependency
- **Works standalone** — every script runs independently, with or without Claude Code

---

## Table of Contents

- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Capabilities](#capabilities)
- [Full Pipeline](#full-pipeline)
- [Scripts Reference](#scripts-reference)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)
- [Agent Compatibility](#agent-compatibility)
- [Contributing](#contributing)
- [License](#license)

---

## Requirements

You must have the following installed on your machine before using this skill.

| Dependency | Required | Purpose | Install |
|:-----------|:--------:|:--------|:--------|
| **FFmpeg** | Yes | All video processing (trim, jump cut, overlay, speed, caption burning) | See below |
| **ffprobe** | Yes | Media analysis (ships with FFmpeg) | Included with FFmpeg |
| **Whisper** | For captions | Audio transcription to SRT subtitle files | See below |
| **Bash** | Yes | Script runtime | Pre-installed on macOS/Linux |
| **Python 3** | For captions | Required by Whisper | Pre-installed on most systems |

### Install FFmpeg

```bash
# macOS (Homebrew)
brew install ffmpeg

# Ubuntu / Debian
sudo apt install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg

# Windows (Chocolatey)
choco install ffmpeg
```

### Install Whisper (optional — only needed for captions)

```bash
pip install openai-whisper
```

> Whisper runs locally on your machine. No API keys, no cloud calls, no data leaves your computer.

### Verify Installation

```bash
ffmpeg -version     # should print version info
ffprobe -version    # should print version info
whisper --help      # should print usage (only if you need captions)
```

Or run the onboard script to check everything at once:

```bash
./scripts/onboard.sh --check
```

---

## Quick Start

### Install the Skill

The onboard script checks dependencies, makes scripts executable, and registers the skill with OpenClaw and Claude Code:

```bash
./scripts/onboard.sh
```

<details>
<summary><strong>Onboard options</strong></summary>

| Flag | Description |
|:-----|:------------|
| *(no flag)* | Default — symlinks skill to `~/.openclaw/skills/` and `~/.claude/skills/` |
| `--copy` | Copy files instead of symlinking |
| `--check` | Check dependencies only, don't install |
| `--uninstall` | Remove the skill from all locations |

</details>

### Run Your First Edit

```bash
# Remove silence from a video
bash scripts/jumpcut.sh ~/video.mp4

# Trim to a specific range
bash scripts/trim.sh ~/video.mp4 --start 00:01:00 --end 00:05:00

# Full pipeline: trim, remove silence, add captions, speed up
bash scripts/edit.sh ~/video.mp4 \
  --trim-start 00:00:10 --trim-end 00:10:00 \
  --jumpcut \
  --caption --caption-style hormozi \
  --speed 1.25 \
  --output final.mp4
```

That's it. No install step, no config files, no build process.

---

## Capabilities

### Trimming

Cut video to specific start/end timestamps or duration. Uses fast codec copying — no re-encoding.

```bash
scripts/trim.sh video.mp4 --start 00:01:30 --end 00:05:00
```

| Option | Description | Default |
|:-------|:------------|:--------|
| `--start` | Start timestamp (HH:MM:SS or seconds) | `00:00:00` |
| `--end` | End timestamp | End of file |
| `--output` | Output path | `{name}_trimmed.{ext}` |

### Jump Cuts (Silence Removal)

Auto-detects and removes silent sections. Reports time saved and percentage removed.

```bash
scripts/jumpcut.sh video.mp4 --threshold -30 --duration 0.5 --padding 0.1
```

| Option | Description | Default |
|:-------|:------------|:--------|
| `--threshold` | Silence threshold in dB | `-30` |
| `--duration` | Min silence duration to cut (seconds) | `0.5` |
| `--padding` | Padding around speech (seconds) | `0.1` |
| `--output` | Output path | `{name}_jumpcut.{ext}` |

### Captions

Two-step process: transcribe audio with Whisper, then burn subtitles into the video.

**Step 1 — Transcribe:**

```bash
scripts/transcribe.sh video.mp4 --model base --language en
```

**Step 2 — Burn captions:**

```bash
scripts/caption.sh video.mp4 video.srt --style hormozi
```

#### Caption Styles

| Style | Description |
|:------|:------------|
| **hormozi** | Bold, centered, large — Alex Hormozi word-by-word impact style |
| **standard** | Traditional bottom subtitles with semi-transparent background |
| **minimal** | Small lower-third captions, clean and unobtrusive |

<details>
<summary><strong>Whisper Model Options</strong></summary>

| Model | Speed | Accuracy | Best For |
|:------|:------|:---------|:---------|
| `tiny` | Fastest | Low | Quick drafts, testing |
| `base` | Fast | Good | Most videos (default) |
| `small` | Medium | Better | Noisy audio |
| `medium` | Slow | High | Long-form content |
| `large` | Slowest | Highest | Maximum accuracy |

</details>

### Text Overlays

Add positioned text at specific timestamps with configurable appearance.

```bash
scripts/overlay-text.sh video.mp4 \
  --text "Subscribe!" \
  --start 00:01:00 --end 00:01:05 \
  --position bottom-right \
  --fontsize 48 --color white
```

| Option | Description | Default |
|:-------|:------------|:--------|
| `--text` | Text to display | *(required)* |
| `--position` | Placement (see below) | `center` |
| `--start` | Display start time | `00:00:00` |
| `--end` | Display end time | End of file |
| `--fontsize` | Font size in pixels | `48` |
| `--color` | Font color | `white` |
| `--bg-color` | Background color with opacity | *(none)* |

**Positions:** `center` &bull; `top` &bull; `bottom` &bull; `top-left` &bull; `top-right` &bull; `bottom-left` &bull; `bottom-right`

### Speed Changes

Adjust playback speed with pitch-corrected audio. Handles extreme values via automatic filter chaining.

```bash
scripts/edit.sh video.mp4 --speed 1.5
```

---

## Full Pipeline

The `edit.sh` orchestrator chains multiple operations in a single command. Operations execute in this order:

```
trim → jump cut → speed → caption → overlay
```

```bash
scripts/edit.sh video.mp4 \
  --trim-start 00:00:10 --trim-end 00:10:00 \
  --jumpcut \
  --jumpcut-threshold -25 \
  --caption --caption-style hormozi \
  --speed 1.25 \
  --overlay-text "Like & Subscribe" \
  --overlay-start 00:01:00 --overlay-end 00:01:05 \
  --output final.mp4
```

<details>
<summary><strong>All Pipeline Options</strong></summary>

| Option | Description |
|:-------|:------------|
| `--trim-start` | Trim start timestamp |
| `--trim-end` | Trim end timestamp |
| `--jumpcut` | Enable silence removal |
| `--jumpcut-threshold` | Silence threshold (dB) |
| `--jumpcut-duration` | Min silence duration (seconds) |
| `--jumpcut-padding` | Padding around speech (seconds) |
| `--speed` | Playback speed multiplier |
| `--caption` | Enable captioning (auto-transcribes) |
| `--caption-style` | Caption style: hormozi, standard, minimal |
| `--caption-srt` | Use existing SRT file instead of transcribing |
| `--caption-model` | Whisper model for transcription |
| `--caption-language` | Language code for transcription |
| `--overlay-text` | Text overlay content |
| `--overlay-start` | Overlay start timestamp |
| `--overlay-end` | Overlay end timestamp |
| `--overlay-position` | Overlay position |
| `--overlay-fontsize` | Overlay font size |
| `--overlay-color` | Overlay font color |
| `--output` | Final output path |

</details>

Intermediate files are automatically cleaned up. The pipeline reports output file path, duration, and file size on completion.

---

## Scripts Reference

| Script | Purpose | Output |
|:-------|:--------|:-------|
| `scripts/edit.sh` | Main orchestrator — chains all operations | `{name}_edited.{ext}` |
| `scripts/trim.sh` | Trim by timestamps | `{name}_trimmed.{ext}` |
| `scripts/jumpcut.sh` | Remove silence via silencedetect | `{name}_jumpcut.{ext}` |
| `scripts/transcribe.sh` | Whisper transcription to SRT | `{name}.srt` |
| `scripts/caption.sh` | Burn SRT captions with style | `{name}_captioned.{ext}` |
| `scripts/overlay-text.sh` | Add positioned text overlays | `{name}_overlay.{ext}` |

All scripts accept `--help` and include usage documentation in their headers.

---

## Configuration

| Environment Variable | Required | Default | Description |
|:---------------------|:--------:|:--------|:------------|
| `WHISPER_BIN` | No | Auto-detected | Path to whisper binary |

No config files, no JSON manifests. Every option is a command-line flag with sensible defaults.

---

## Troubleshooting

<details>
<summary><strong>"ffmpeg: command not found"</strong></summary>

Install FFmpeg for your platform:

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install ffmpeg

# Verify
ffmpeg -version
```

</details>

<details>
<summary><strong>"whisper not found"</strong></summary>

Install OpenAI Whisper:

```bash
pip install openai-whisper

# Or set a custom path
export WHISPER_BIN=/path/to/whisper
```

</details>

<details>
<summary><strong>Jump cut removes too much / too little</strong></summary>

Tune the silence detection parameters:

```bash
# More aggressive (removes more silence)
scripts/jumpcut.sh video.mp4 --threshold -25 --duration 0.3

# More conservative (keeps more pauses)
scripts/jumpcut.sh video.mp4 --threshold -35 --duration 1.0 --padding 0.3
```

</details>

<details>
<summary><strong>Captions are inaccurate</strong></summary>

Use a larger Whisper model for better accuracy:

```bash
scripts/transcribe.sh video.mp4 --model medium
# or for maximum accuracy:
scripts/transcribe.sh video.mp4 --model large
```

You can also specify the language explicitly:

```bash
scripts/transcribe.sh video.mp4 --model medium --language en
```

</details>

---

## Project Structure

```
video-editing-skill/
  SKILL.md                  # Skill metadata for AI agents
  README.md                 # This file
  LICENSE                   # MIT License
  scripts/
    onboard.sh              # Setup: dependency check + skill install
    edit.sh                 # Pipeline orchestrator
    trim.sh                 # Video trimming
    jumpcut.sh              # Silence removal
    transcribe.sh           # Whisper transcription
    caption.sh              # Caption burning (3 styles)
    overlay-text.sh         # Text overlay insertion
```

---

## Agent Compatibility

This skill is built for **Claude Code** and follows the skill metadata convention via `SKILL.md`. It also works with any AI agent that can execute shell commands.

**Natural language examples:**

```
Edit my video at ~/video.mp4 — remove silence, add Hormozi-style captions, and speed it up 1.25x
```

```
Trim ~/interview.mp4 from 00:02:00 to 00:15:00 and add standard captions
```

```
Add a "Subscribe!" text overlay at the 1 minute mark in ~/video.mp4
```

The agent reads `SKILL.md`, identifies the operations needed, and calls the appropriate scripts.

---

## Contributing

Contributions welcome! Please:

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Test your changes against real video files
4. Submit a PR

---

## License

[MIT](LICENSE)
</div>
