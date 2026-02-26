#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# video-editing-skill — Onboard Script
#
# Checks system dependencies, makes scripts executable,
# and installs the skill for OpenClaw / Claude Code.
#
# Usage:
#   ./scripts/onboard.sh              # install (symlink mode)
#   ./scripts/onboard.sh --copy       # install (copy mode)
#   ./scripts/onboard.sh --uninstall  # remove skill
#   ./scripts/onboard.sh --check      # dependency check only
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
SKILL_NAME="video-editing-skill"

# OpenClaw / Claude Code standard paths
OPENCLAW_SKILLS_DIR="${HOME}/.openclaw/skills"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"

MODE="link"
if [[ "${1:-}" == "--copy" ]]; then
  MODE="copy"
elif [[ "${1:-}" == "--uninstall" ]]; then
  MODE="uninstall"
elif [[ "${1:-}" == "--check" ]]; then
  MODE="check"
fi

# ── Helpers ──────────────────────────────────────────────────

has_cmd() { command -v "$1" &>/dev/null; }

print_header() {
  echo ""
  echo "  video-editing-skill"
  echo "  ==================="
  echo "  6 scripts | FFmpeg + Whisper | Bash"
  echo ""
}

print_ok()   { printf "    %-18s %s\n" "$1" "OK ($2)"; }
print_fail() { printf "    %-18s %s\n" "$1" "MISSING"; }
print_skip() { printf "    %-18s %s\n" "$1" "SKIP ($2)"; }

# ── Uninstall ────────────────────────────────────────────────

if [[ "$MODE" == "uninstall" ]]; then
  print_header
  echo "  Uninstalling..."
  echo ""

  removed=0

  for skills_dir in "$OPENCLAW_SKILLS_DIR" "$CLAUDE_SKILLS_DIR"; do
    target="$skills_dir/$SKILL_NAME"
    if [[ -L "$target" || -d "$target" ]]; then
      rm -rf "$target"
      echo "  [-] removed: $target"
      removed=$((removed + 1))
    fi
  done

  if [[ $removed -eq 0 ]]; then
    echo "  Nothing to remove."
  fi

  echo ""
  echo "  Done."
  echo ""
  exit 0
fi

# ── Preflight: Check Dependencies ────────────────────────────

print_header

echo "  [1/3] Checking dependencies"
echo "  ---------------------------"

errors=0
warnings=0

# FFmpeg (required)
if has_cmd ffmpeg; then
  version="$(ffmpeg -version 2>/dev/null | head -1 | sed 's/ffmpeg version \([^ ]*\).*/\1/')"
  print_ok "ffmpeg" "$version"
else
  print_fail "ffmpeg"
  errors=$((errors + 1))
fi

# ffprobe (required, ships with FFmpeg)
if has_cmd ffprobe; then
  print_ok "ffprobe" "bundled with ffmpeg"
else
  print_fail "ffprobe"
  errors=$((errors + 1))
fi

# Whisper (optional — only needed for captions)
whisper_missing=false
if has_cmd whisper; then
  print_ok "whisper" "captions enabled"
else
  print_skip "whisper" "captions unavailable"
  whisper_missing=true
  warnings=$((warnings + 1))
fi

# Bash version check
bash_version="${BASH_VERSION%%(*}"
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
  print_ok "bash" "$bash_version"
else
  print_ok "bash" "$bash_version — v4+ recommended"
  warnings=$((warnings + 1))
fi

echo ""

if [[ $errors -gt 0 ]]; then
  echo "  BLOCKED: $errors required dependency missing."
  echo ""
  echo "  Install FFmpeg:"
  echo "    macOS:        brew install ffmpeg"
  echo "    Ubuntu/Debian: sudo apt install ffmpeg"
  echo "    Arch:          sudo pacman -S ffmpeg"
  echo "    Windows:       choco install ffmpeg"
  echo ""
  if [[ "$MODE" == "check" ]]; then
    exit 1
  fi
  echo "  Continuing setup anyway (scripts will fail without FFmpeg)."
  echo ""
fi

if [[ "$whisper_missing" == true ]]; then
  echo "  Whisper not found (optional — only needed for captions)."
  echo "  Install: pip install openai-whisper"
  echo ""
fi

if [[ "$MODE" == "check" ]]; then
  if [[ $errors -eq 0 ]]; then
    echo "  All required dependencies found."
  fi
  echo ""
  exit 0
fi

# ── Step 2: Make Scripts Executable ──────────────────────────

echo "  [2/3] Making scripts executable"
echo "  --------------------------------"

for script in "$SCRIPT_DIR"/*.sh; do
  name="$(basename "$script")"
  if [[ ! -x "$script" ]]; then
    chmod +x "$script"
    printf "    %-18s %s\n" "$name" "chmod +x"
  else
    printf "    %-18s %s\n" "$name" "already executable"
  fi
done

echo ""

# ── Step 3: Install Skill ───────────────────────────────────

echo "  [3/3] Installing skill"
echo "  ----------------------"

install_skill() {
  local skills_dir="$1"
  local label="$2"
  local target="$skills_dir/$SKILL_NAME"

  mkdir -p "$skills_dir"

  printf "    %-18s" "$label"

  if [[ "$MODE" == "copy" ]]; then
    if [[ -d "$target" && ! -L "$target" ]]; then
      echo "already installed (copy)"
    else
      rm -f "$target"
      cp -R "$SKILL_ROOT" "$target"
      echo "copied"
    fi
  else
    if [[ -L "$target" ]]; then
      existing="$(readlink "$target")"
      if [[ "$existing" == "$SKILL_ROOT" ]]; then
        echo "already linked"
      else
        rm -f "$target"
        ln -s "$SKILL_ROOT" "$target"
        echo "re-linked (was: $existing)"
      fi
    elif [[ -e "$target" ]]; then
      echo "EXISTS (not a symlink, skipping)"
    else
      ln -s "$SKILL_ROOT" "$target"
      echo "linked"
    fi
  fi
}

install_skill "$OPENCLAW_SKILLS_DIR" "openclaw"
install_skill "$CLAUDE_SKILLS_DIR" "claude-code"

echo ""

# ── Verify ───────────────────────────────────────────────────

echo "  Verification"
echo "  ------------"

verify_errors=0

# Check SKILL.md
if [[ -f "$SKILL_ROOT/SKILL.md" ]]; then
  printf "    %-18s %s\n" "SKILL.md" "OK"
else
  printf "    %-18s %s\n" "SKILL.md" "MISSING"
  verify_errors=$((verify_errors + 1))
fi

# Check all scripts exist and are executable
for script in edit.sh trim.sh jumpcut.sh transcribe.sh caption.sh overlay-text.sh; do
  if [[ -x "$SCRIPT_DIR/$script" ]]; then
    printf "    %-18s %s\n" "$script" "OK"
  elif [[ -f "$SCRIPT_DIR/$script" ]]; then
    printf "    %-18s %s\n" "$script" "exists (not executable)"
    verify_errors=$((verify_errors + 1))
  else
    printf "    %-18s %s\n" "$script" "MISSING"
    verify_errors=$((verify_errors + 1))
  fi
done

# Check skill symlinks
for skills_dir in "$OPENCLAW_SKILLS_DIR" "$CLAUDE_SKILLS_DIR"; do
  target="$skills_dir/$SKILL_NAME"
  label="$(basename "$(dirname "$target")")"
  if [[ -e "$target/SKILL.md" ]]; then
    printf "    %-18s %s\n" "$label install" "OK"
  else
    printf "    %-18s %s\n" "$label install" "NOT FOUND"
    verify_errors=$((verify_errors + 1))
  fi
done

echo ""

if [[ $verify_errors -gt 0 ]]; then
  echo "  WARNING: $verify_errors issue(s) found. Check output above."
else
  echo "  All checks passed."
fi

# ── Summary ──────────────────────────────────────────────────

echo ""
echo "  =============================="
echo "  Onboard complete!"
echo ""
echo "  Next steps:"
echo ""

if ! has_cmd ffmpeg; then
  echo "  1. Install FFmpeg (required):"
  echo "     brew install ffmpeg"
  echo ""
fi

if ! has_cmd whisper; then
  echo "  2. Install Whisper (optional, for captions):"
  echo "     pip install openai-whisper"
  echo ""
fi

echo "  Try it out:"
echo ""
echo "    \"Edit my video at ~/video.mp4 — remove silence and add captions\""
echo ""
echo "  Or run scripts directly:"
echo ""
echo "    bash scripts/jumpcut.sh ~/video.mp4"
echo "    bash scripts/trim.sh ~/video.mp4 --start 00:01:00 --end 00:05:00"
echo "    bash scripts/edit.sh ~/video.mp4 --jumpcut --caption --speed 1.25"
echo ""
