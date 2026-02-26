#!/usr/bin/env bash
set -euo pipefail

# caption.sh — Burn SRT captions into video with style options
#
# Usage: ./caption.sh <input_video> <srt_file> [options]
#
# Options:
#   --style <style>    Caption style: hormozi, standard, minimal (default: standard)
#   --output <path>    Output video path (default: <input>_captioned.<ext>)
#
# Styles:
#   hormozi   — Bold, centered, large word-by-word captions (Alex Hormozi style)
#   standard  — Traditional bottom subtitles with semi-transparent background
#   minimal   — Small lower-third captions, clean and unobtrusive
#
# Examples:
#   ./caption.sh video.mp4 video.srt
#   ./caption.sh video.mp4 video.srt --style hormozi
#   ./caption.sh video.mp4 video.srt --style minimal --output final.mp4

print_usage() {
    sed -n '3,15p' "$0" | sed 's/^# \?//'
}

if [[ $# -lt 2 ]]; then
    print_usage
    exit 1
fi

INPUT_VIDEO="$1"
SRT_FILE="$2"
shift 2

STYLE="standard"
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --style)
            STYLE="$2"
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

if [[ ! -f "$SRT_FILE" ]]; then
    echo "Error: SRT file not found: $SRT_FILE"
    exit 1
fi

INPUT_DIR="$(dirname "$INPUT_VIDEO")"
INPUT_BASENAME="$(basename "$INPUT_VIDEO" | sed 's/\.[^.]*$//')"
INPUT_EXT="$(basename "$INPUT_VIDEO" | sed 's/.*\.//')"

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT_DIR}/${INPUT_BASENAME}_captioned.${INPUT_EXT}"
fi

# Escape paths for ffmpeg subtitle filter (colons and backslashes)
escape_path() {
    local path="$1"
    path="${path//\\/\\\\}"
    path="${path//:/\\:}"
    path="${path//'/\\'}"
    echo "$path"
}

ESCAPED_SRT="$(escape_path "$SRT_FILE")"

build_subtitle_filter() {
    local style="$1"
    local srt_path="$2"

    case "$style" in
        hormozi)
            # Bold, centered, large — Hormozi-style word-by-word impact captions
            echo "subtitles='${srt_path}':force_style='FontName=Arial Black,FontSize=28,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,Outline=3,Shadow=2,Alignment=10,MarginV=40'"
            ;;
        standard)
            # Traditional bottom subtitles with background box
            echo "subtitles='${srt_path}':force_style='FontName=Arial,FontSize=20,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,Outline=1,Shadow=1,Alignment=2,BorderStyle=4,MarginV=30'"
            ;;
        minimal)
            # Small lower-third, clean
            echo "subtitles='${srt_path}':force_style='FontName=Helvetica Neue,FontSize=16,PrimaryColour=&H00FFFFFF,OutlineColour=&H40000000,Outline=1,Shadow=0,Alignment=1,MarginV=20,MarginL=40'"
            ;;
        *)
            echo "Error: Unknown style '$style'. Use: hormozi, standard, minimal" >&2
            exit 1
            ;;
    esac
}

SUBTITLE_FILTER="$(build_subtitle_filter "$STYLE" "$ESCAPED_SRT")"

echo "Burning captions into video"
echo "Style: $STYLE"
echo "Input: $INPUT_VIDEO"
echo "SRT: $SRT_FILE"

ffmpeg -y -i "$INPUT_VIDEO" \
    -vf "$SUBTITLE_FILTER" \
    -c:a copy \
    "$OUTPUT" 2>&1 | tail -5

echo "Output: $OUTPUT"
