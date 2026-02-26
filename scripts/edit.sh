#!/usr/bin/env bash
set -euo pipefail

# edit.sh — Main orchestrator for video editing operations
#
# Usage: ./edit.sh <input_video> [operations...]
#
# Operations (applied in order):
#   --trim-start <ts>      Trim: set start time
#   --trim-end <ts>        Trim: set end time
#   --trim-duration <sec>  Trim: set duration from start
#   --jumpcut              Remove silence/dead air
#   --jumpcut-threshold <dB>   Silence threshold (default: -30)
#   --jumpcut-duration <sec>   Min silence to cut (default: 0.5)
#   --jumpcut-padding <sec>    Padding around speech (default: 0.1)
#   --caption              Add captions (transcribe + burn in)
#   --caption-style <style>    hormozi, standard, minimal (default: standard)
#   --caption-model <model>    Whisper model (default: base)
#   --caption-language <lang>  Language code (default: auto)
#   --caption-srt <path>       Use existing SRT instead of transcribing
#   --overlay-text <text>      Add text overlay
#   --overlay-start <ts>       Overlay start time (default: 0)
#   --overlay-end <ts>         Overlay end time (default: start+5)
#   --overlay-position <pos>   center, top, bottom, etc. (default: center)
#   --overlay-fontsize <size>  Font size (default: 48)
#   --speed <factor>       Speed change (e.g., 1.5 for 1.5x, 0.5 for half speed)
#   --output <path>        Final output path (default: <input>_edited.<ext>)
#
# Examples:
#   ./edit.sh video.mp4 --jumpcut --caption --caption-style hormozi
#   ./edit.sh video.mp4 --trim-start 00:00:10 --trim-end 00:05:00 --speed 1.25
#   ./edit.sh video.mp4 --jumpcut --overlay-text "Subscribe!" --overlay-start 00:01:00

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

print_usage() {
    sed -n '3,28p' "$0" | sed 's/^# \?//'
}

if [[ $# -lt 1 ]]; then
    print_usage
    exit 1
fi

INPUT_VIDEO="$1"
shift

if [[ ! -f "$INPUT_VIDEO" ]]; then
    echo "Error: Input video not found: $INPUT_VIDEO"
    exit 1
fi

# Operation flags
DO_TRIM=false
TRIM_START=""
TRIM_END=""
TRIM_DURATION=""

DO_JUMPCUT=false
JUMPCUT_THRESHOLD="-30"
JUMPCUT_DURATION="0.5"
JUMPCUT_PADDING="0.1"

DO_CAPTION=false
CAPTION_STYLE="standard"
CAPTION_MODEL="base"
CAPTION_LANGUAGE=""
CAPTION_SRT=""

DO_OVERLAY=false
OVERLAY_TEXT=""
OVERLAY_START="0"
OVERLAY_END=""
OVERLAY_POSITION="center"
OVERLAY_FONTSIZE="48"

DO_SPEED=false
SPEED_FACTOR=""

OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --trim-start)
            DO_TRIM=true
            TRIM_START="$2"
            shift 2
            ;;
        --trim-end)
            DO_TRIM=true
            TRIM_END="$2"
            shift 2
            ;;
        --trim-duration)
            DO_TRIM=true
            TRIM_DURATION="$2"
            shift 2
            ;;
        --jumpcut)
            DO_JUMPCUT=true
            shift
            ;;
        --jumpcut-threshold)
            JUMPCUT_THRESHOLD="$2"
            shift 2
            ;;
        --jumpcut-duration)
            JUMPCUT_DURATION="$2"
            shift 2
            ;;
        --jumpcut-padding)
            JUMPCUT_PADDING="$2"
            shift 2
            ;;
        --caption)
            DO_CAPTION=true
            shift
            ;;
        --caption-style)
            CAPTION_STYLE="$2"
            shift 2
            ;;
        --caption-model)
            CAPTION_MODEL="$2"
            shift 2
            ;;
        --caption-language)
            CAPTION_LANGUAGE="$2"
            shift 2
            ;;
        --caption-srt)
            CAPTION_SRT="$2"
            shift 2
            ;;
        --overlay-text)
            DO_OVERLAY=true
            OVERLAY_TEXT="$2"
            shift 2
            ;;
        --overlay-start)
            OVERLAY_START="$2"
            shift 2
            ;;
        --overlay-end)
            OVERLAY_END="$2"
            shift 2
            ;;
        --overlay-position)
            OVERLAY_POSITION="$2"
            shift 2
            ;;
        --overlay-fontsize)
            OVERLAY_FONTSIZE="$2"
            shift 2
            ;;
        --speed)
            DO_SPEED=true
            SPEED_FACTOR="$2"
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

INPUT_DIR="$(dirname "$INPUT_VIDEO")"
INPUT_BASENAME="$(basename "$INPUT_VIDEO" | sed 's/\.[^.]*$//')"
INPUT_EXT="$(basename "$INPUT_VIDEO" | sed 's/.*\.//')"

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT_DIR}/${INPUT_BASENAME}_edited.${INPUT_EXT}"
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

CURRENT_FILE="$INPUT_VIDEO"
STEP=0

next_intermediate() {
    STEP=$((STEP + 1))
    echo "${WORK_DIR}/step_${STEP}.${INPUT_EXT}"
}

echo "=== Video Edit Pipeline ==="
echo "Input: $INPUT_VIDEO"
echo ""

# Step 1: Trim
if [[ "$DO_TRIM" == true ]]; then
    echo "--- Step: Trim ---"
    NEXT="$(next_intermediate)"
    TRIM_ARGS=("$CURRENT_FILE")
    [[ -n "$TRIM_START" ]] && TRIM_ARGS+=(--start "$TRIM_START")
    [[ -n "$TRIM_END" ]] && TRIM_ARGS+=(--end "$TRIM_END")
    [[ -n "$TRIM_DURATION" ]] && TRIM_ARGS+=(--duration "$TRIM_DURATION")
    TRIM_ARGS+=(--output "$NEXT")

    bash "${SCRIPT_DIR}/trim.sh" "${TRIM_ARGS[@]}"
    CURRENT_FILE="$NEXT"
    echo ""
fi

# Step 2: Jump cuts (remove silence)
if [[ "$DO_JUMPCUT" == true ]]; then
    echo "--- Step: Jump Cut ---"
    NEXT="$(next_intermediate)"
    bash "${SCRIPT_DIR}/jumpcut.sh" "$CURRENT_FILE" \
        --threshold "$JUMPCUT_THRESHOLD" \
        --duration "$JUMPCUT_DURATION" \
        --padding "$JUMPCUT_PADDING" \
        --output "$NEXT"
    CURRENT_FILE="$NEXT"
    echo ""
fi

# Step 3: Speed change
if [[ "$DO_SPEED" == true ]]; then
    echo "--- Step: Speed Change (${SPEED_FACTOR}x) ---"
    NEXT="$(next_intermediate)"

    # Calculate inverse for video PTS
    VIDEO_PTS="$(awk "BEGIN { printf \"%.6f\", 1.0 / $SPEED_FACTOR }")"

    # Audio tempo filter (must be between 0.5 and 100.0)
    # Chain multiple atempo filters for extreme values
    build_atempo() {
        local factor="$1"
        local filters=""

        # Handle factors > 2.0 by chaining
        while awk "BEGIN { exit !($factor > 2.0) }"; do
            if [[ -n "$filters" ]]; then
                filters="${filters},"
            fi
            filters="${filters}atempo=2.0"
            factor="$(awk "BEGIN { printf \"%.6f\", $factor / 2.0 }")"
        done

        # Handle factors < 0.5 by chaining
        while awk "BEGIN { exit !($factor < 0.5) }"; do
            if [[ -n "$filters" ]]; then
                filters="${filters},"
            fi
            filters="${filters}atempo=0.5"
            factor="$(awk "BEGIN { printf \"%.6f\", $factor / 0.5 }")"
        done

        if [[ -n "$filters" ]]; then
            filters="${filters},"
        fi
        filters="${filters}atempo=${factor}"
        echo "$filters"
    }

    ATEMPO_FILTER="$(build_atempo "$SPEED_FACTOR")"

    ffmpeg -y -i "$CURRENT_FILE" \
        -vf "setpts=${VIDEO_PTS}*PTS" \
        -af "$ATEMPO_FILTER" \
        "$NEXT" 2>&1 | tail -3

    CURRENT_FILE="$NEXT"
    echo "Speed adjusted to ${SPEED_FACTOR}x"
    echo ""
fi

# Step 4: Caption (transcribe + burn in)
if [[ "$DO_CAPTION" == true ]]; then
    echo "--- Step: Caption ---"

    if [[ -n "$CAPTION_SRT" && -f "$CAPTION_SRT" ]]; then
        SRT_FILE="$CAPTION_SRT"
        echo "Using existing SRT: $SRT_FILE"
    else
        echo "Transcribing with Whisper..."
        SRT_FILE="${WORK_DIR}/captions.srt"
        TRANSCRIBE_ARGS=("$CURRENT_FILE" --model "$CAPTION_MODEL" --output "$SRT_FILE")
        [[ -n "$CAPTION_LANGUAGE" ]] && TRANSCRIBE_ARGS+=(--language "$CAPTION_LANGUAGE")
        bash "${SCRIPT_DIR}/transcribe.sh" "${TRANSCRIBE_ARGS[@]}"
    fi

    NEXT="$(next_intermediate)"
    bash "${SCRIPT_DIR}/caption.sh" "$CURRENT_FILE" "$SRT_FILE" \
        --style "$CAPTION_STYLE" \
        --output "$NEXT"
    CURRENT_FILE="$NEXT"
    echo ""
fi

# Step 5: Text overlay
if [[ "$DO_OVERLAY" == true ]]; then
    echo "--- Step: Text Overlay ---"
    NEXT="$(next_intermediate)"
    OVERLAY_ARGS=("$CURRENT_FILE" --text "$OVERLAY_TEXT")
    OVERLAY_ARGS+=(--start "$OVERLAY_START")
    [[ -n "$OVERLAY_END" ]] && OVERLAY_ARGS+=(--end "$OVERLAY_END")
    OVERLAY_ARGS+=(--position "$OVERLAY_POSITION")
    OVERLAY_ARGS+=(--fontsize "$OVERLAY_FONTSIZE")
    OVERLAY_ARGS+=(--output "$NEXT")

    bash "${SCRIPT_DIR}/overlay-text.sh" "${OVERLAY_ARGS[@]}"
    CURRENT_FILE="$NEXT"
    echo ""
fi

# Final: copy to output
if [[ "$CURRENT_FILE" != "$OUTPUT" ]]; then
    cp "$CURRENT_FILE" "$OUTPUT"
fi

echo "=== Pipeline Complete ==="
echo "Output: $OUTPUT"

# Show file info
OUTPUT_DURATION="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT" 2>/dev/null || echo "unknown")"
OUTPUT_SIZE="$(du -h "$OUTPUT" | cut -f1)"
echo "Duration: ${OUTPUT_DURATION}s | Size: ${OUTPUT_SIZE}"
