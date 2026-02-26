#!/usr/bin/env bash
set -euo pipefail

# trim.sh — Trim video by start/end timestamps
#
# Usage: ./trim.sh <input_video> [options]
#
# Options:
#   --start <timestamp>  Start time (default: 00:00:00) — format: HH:MM:SS or seconds
#   --end <timestamp>    End time (default: end of video) — format: HH:MM:SS or seconds
#   --duration <time>    Duration from start (alternative to --end)
#   --output <path>      Output path (default: <input>_trimmed.<ext>)
#
# Examples:
#   ./trim.sh video.mp4 --start 00:01:30 --end 00:05:00
#   ./trim.sh video.mp4 --start 10 --duration 60
#   ./trim.sh video.mp4 --start 00:00:30 --output clip.mp4

print_usage() {
    sed -n '3,14p' "$0" | sed 's/^# \?//'
}

if [[ $# -lt 1 ]]; then
    print_usage
    exit 1
fi

INPUT_VIDEO="$1"
shift

START=""
END=""
DURATION=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start)
            START="$2"
            shift 2
            ;;
        --end)
            END="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
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

if [[ -z "$START" && -z "$END" && -z "$DURATION" ]]; then
    echo "Error: Specify at least --start, --end, or --duration"
    print_usage
    exit 1
fi

INPUT_DIR="$(dirname "$INPUT_VIDEO")"
INPUT_BASENAME="$(basename "$INPUT_VIDEO" | sed 's/\.[^.]*$//')"
INPUT_EXT="$(basename "$INPUT_VIDEO" | sed 's/.*\.//')"

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT_DIR}/${INPUT_BASENAME}_trimmed.${INPUT_EXT}"
fi

FFMPEG_ARGS=(-y -i "$INPUT_VIDEO")

if [[ -n "$START" ]]; then
    FFMPEG_ARGS+=(-ss "$START")
fi

if [[ -n "$END" ]]; then
    FFMPEG_ARGS+=(-to "$END")
elif [[ -n "$DURATION" ]]; then
    FFMPEG_ARGS+=(-t "$DURATION")
fi

FFMPEG_ARGS+=(-c copy -avoid_negative_ts make_zero "$OUTPUT")

echo "Trimming video"
echo "Input: $INPUT_VIDEO"
echo "Start: ${START:-beginning}"
echo "End: ${END:-${DURATION:+${START:-0}+${DURATION}}}"

ffmpeg "${FFMPEG_ARGS[@]}" 2>&1 | tail -3

echo "Output: $OUTPUT"
