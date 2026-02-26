#!/usr/bin/env bash
set -euo pipefail

# transcribe.sh — Transcribe video/audio to SRT using Whisper
#
# Usage: ./transcribe.sh <input_file> [options]
#
# Options:
#   --model <model>      Whisper model: tiny, base, small, medium, large (default: base)
#   --language <lang>    Language code, e.g. en, es, fr (default: auto-detect)
#   --output <path>      Output SRT path (default: <input_basename>.srt)
#
# Examples:
#   ./transcribe.sh video.mp4
#   ./transcribe.sh video.mp4 --model medium --language en
#   ./transcribe.sh video.mp4 --output /tmp/captions.srt

WHISPER_BIN="${WHISPER_BIN:-$(command -v whisper 2>/dev/null || echo "whisper")}"

print_usage() {
    sed -n '3,12p' "$0" | sed 's/^# \?//'
}

if [[ $# -lt 1 ]]; then
    print_usage
    exit 1
fi

INPUT_FILE="$1"
shift

MODEL="base"
LANGUAGE=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option '$1'"
            print_usage
            exit 1
            ;;
    esac
done

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

if ! command -v "$WHISPER_BIN" &>/dev/null; then
    echo "Error: whisper not found at $WHISPER_BIN"
    echo "Install: pip install openai-whisper"
    exit 1
fi

INPUT_DIR="$(dirname "$INPUT_FILE")"
INPUT_BASENAME="$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

LANG_FLAG=""
if [[ -n "$LANGUAGE" ]]; then
    LANG_FLAG="--language $LANGUAGE"
fi

echo "Transcribing: $INPUT_FILE"
echo "Model: $MODEL"
echo "Language: ${LANGUAGE:-auto-detect}"

"$WHISPER_BIN" "$INPUT_FILE" \
    --model "$MODEL" \
    --output_format srt \
    --output_dir "$TEMP_DIR" \
    $LANG_FLAG

SRT_FILE="$(find "$TEMP_DIR" -name '*.srt' -type f | head -1)"

if [[ -z "$SRT_FILE" || ! -f "$SRT_FILE" ]]; then
    echo "Error: Whisper did not produce an SRT file"
    exit 1
fi

if [[ -n "$OUTPUT" ]]; then
    FINAL_OUTPUT="$OUTPUT"
else
    FINAL_OUTPUT="${INPUT_DIR}/${INPUT_BASENAME}.srt"
fi

cp "$SRT_FILE" "$FINAL_OUTPUT"

LINE_COUNT="$(wc -l < "$FINAL_OUTPUT" | tr -d ' ')"
echo "Transcription complete: $FINAL_OUTPUT ($LINE_COUNT lines)"
echo "$FINAL_OUTPUT"
