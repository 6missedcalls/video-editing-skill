#!/usr/bin/env bash
set -euo pipefail

# overlay-text.sh — Add text overlays at specific timestamps
#
# Usage: ./overlay-text.sh <input_video> --text <text> [options]
#
# Options:
#   --text <text>        Text to overlay (required)
#   --start <timestamp>  When to show text (default: 00:00:00)
#   --end <timestamp>    When to hide text (default: start + 5 seconds)
#   --position <pos>     Position: center, top, bottom, top-left, top-right,
#                        bottom-left, bottom-right (default: center)
#   --fontsize <size>    Font size (default: 48)
#   --fontcolor <color>  Font color (default: white)
#   --bg <color>         Background color with opacity, e.g. black@0.5 (default: none)
#   --output <path>      Output path (default: <input>_overlay.<ext>)
#
# Examples:
#   ./overlay-text.sh video.mp4 --text "Subscribe!" --start 00:01:00 --end 00:01:05
#   ./overlay-text.sh video.mp4 --text "INTRO" --position top --fontsize 72 --bg black@0.5
#   ./overlay-text.sh video.mp4 --text "Like & Share" --position bottom-right --fontcolor yellow

print_usage() {
    sed -n '3,17p' "$0" | sed 's/^# \?//'
}

if [[ $# -lt 1 ]]; then
    print_usage
    exit 1
fi

INPUT_VIDEO="$1"
shift

TEXT=""
START="0"
END=""
POSITION="center"
FONTSIZE="48"
FONTCOLOR="white"
BG=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --text)
            TEXT="$2"
            shift 2
            ;;
        --start)
            START="$2"
            shift 2
            ;;
        --end)
            END="$2"
            shift 2
            ;;
        --position)
            POSITION="$2"
            shift 2
            ;;
        --fontsize)
            FONTSIZE="$2"
            shift 2
            ;;
        --fontcolor)
            FONTCOLOR="$2"
            shift 2
            ;;
        --bg)
            BG="$2"
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

if [[ ! -f "$INPUT_VIDEO" ]]; then
    echo "Error: Input video not found: $INPUT_VIDEO"
    exit 1
fi

if [[ -z "$TEXT" ]]; then
    echo "Error: --text is required"
    print_usage
    exit 1
fi

INPUT_DIR="$(dirname "$INPUT_VIDEO")"
INPUT_BASENAME="$(basename "$INPUT_VIDEO" | sed 's/\.[^.]*$//')"
INPUT_EXT="$(basename "$INPUT_VIDEO" | sed 's/.*\.//')"

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT_DIR}/${INPUT_BASENAME}_overlay.${INPUT_EXT}"
fi

# Convert timestamp to seconds for ffmpeg enable expression
timestamp_to_seconds() {
    local ts="$1"
    if [[ "$ts" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$ts"
        return
    fi
    # HH:MM:SS or MM:SS
    IFS=: read -ra parts <<< "$ts"
    local seconds=0
    local count="${#parts[@]}"
    if [[ $count -eq 3 ]]; then
        seconds="$(awk "BEGIN { printf \"%.3f\", ${parts[0]} * 3600 + ${parts[1]} * 60 + ${parts[2]} }")"
    elif [[ $count -eq 2 ]]; then
        seconds="$(awk "BEGIN { printf \"%.3f\", ${parts[0]} * 60 + ${parts[1]} }")"
    else
        seconds="${parts[0]}"
    fi
    echo "$seconds"
}

START_SEC="$(timestamp_to_seconds "$START")"

if [[ -n "$END" ]]; then
    END_SEC="$(timestamp_to_seconds "$END")"
else
    END_SEC="$(awk "BEGIN { printf \"%.3f\", $START_SEC + 5 }")"
fi

# Build position coordinates
build_position() {
    local pos="$1"
    local margin=20
    case "$pos" in
        center)
            echo "x=(w-text_w)/2:y=(h-text_h)/2"
            ;;
        top)
            echo "x=(w-text_w)/2:y=${margin}"
            ;;
        bottom)
            echo "x=(w-text_w)/2:y=h-text_h-${margin}"
            ;;
        top-left)
            echo "x=${margin}:y=${margin}"
            ;;
        top-right)
            echo "x=w-text_w-${margin}:y=${margin}"
            ;;
        bottom-left)
            echo "x=${margin}:y=h-text_h-${margin}"
            ;;
        bottom-right)
            echo "x=w-text_w-${margin}:y=h-text_h-${margin}"
            ;;
        *)
            echo "Error: Unknown position '$pos'" >&2
            exit 1
            ;;
    esac
}

POSITION_XY="$(build_position "$POSITION")"

# Escape text for ffmpeg drawtext (colons, single quotes, backslashes)
ESCAPED_TEXT="${TEXT//\\/\\\\\\\\}"
ESCAPED_TEXT="${ESCAPED_TEXT//:/\\:}"
ESCAPED_TEXT="${ESCAPED_TEXT//\'/\'\\\'\'}"

# Build drawtext filter
FILTER="drawtext=text='${ESCAPED_TEXT}':${POSITION_XY}:fontsize=${FONTSIZE}:fontcolor=${FONTCOLOR}"

# Add background box if specified
if [[ -n "$BG" ]]; then
    FILTER="${FILTER}:box=1:boxcolor=${BG}:boxborderw=10"
fi

# Add time enable expression
FILTER="${FILTER}:enable='between(t,${START_SEC},${END_SEC})'"

echo "Adding text overlay"
echo "Text: $TEXT"
echo "Position: $POSITION"
echo "Visible: ${START} → ${END:-+5s}"

ffmpeg -y -i "$INPUT_VIDEO" \
    -vf "$FILTER" \
    -c:a copy \
    "$OUTPUT" 2>&1 | tail -3

echo "Output: $OUTPUT"
