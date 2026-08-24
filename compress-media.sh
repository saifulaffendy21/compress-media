#!/usr/bin/env bash
set -uo pipefail
shopt -s nullglob nocaseglob

PHOTO_QUALITY=85

usage() {
    cat <<'EOF'
Usage:
  ./compress-media.sh /path/to/media-folder

The output is written to:
  /path/to/media-folder-COMPRESSED

Supported input formats:
  JPG, JPEG and MP4 (top-level files only)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ge 1 ]]; then
    INPUT_DIR="$1"
else
    read -r -p "Enter input folder path: " INPUT_DIR
fi

INPUT_DIR="${INPUT_DIR%/}"

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: Folder does not exist: $INPUT_DIR" >&2
    exit 1
fi

INPUT_DIR=$(realpath "$INPUT_DIR")
OUTPUT_DIR="${INPUT_DIR}-COMPRESSED"

for tool in ffmpeg exiftool; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: $tool is not installed." >&2
        exit 1
    fi
done

if command -v magick >/dev/null 2>&1; then
    IMAGE_TOOL="magick"
elif command -v convert >/dev/null 2>&1; then
    IMAGE_TOOL="convert"
else
    echo "Error: ImageMagick is not installed." >&2
    exit 1
fi

if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep 'libx265'; then
    echo "Error: This FFmpeg installation does not provide the libx265 encoder." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

files=(
    "$INPUT_DIR"/*.jpg
    "$INPUT_DIR"/*.jpeg
    "$INPUT_DIR"/*.mp4
)

total=${#files[@]}
processed=0
successful=0
skipped=0
failed=0
timestamp_warnings=0

if ((total == 0)); then
    echo "No JPG, JPEG or MP4 files found in: $INPUT_DIR"
    exit 0
fi

sync_mp4_timestamps() {
    local source_file="$1"
    local destination_file="$2"

    if ! exiftool -overwrite_original \
        -TagsFromFile "$source_file" \
        -Time:All \
        "$destination_file" >/dev/null
    then
        echo "Warning: Could not copy internal MP4 timestamps." >&2
        return 1
    fi

    touch -r "$source_file" "$destination_file"
}

echo
echo "Input folder:  $INPUT_DIR"
echo "Output folder: $OUTPUT_DIR"
echo "Total files:   $total"
echo

for file in "${files[@]}"; do
    filename="${file##*/}"
    base="${filename%.*}"
    extension="${filename##*.}"
    extension="${extension,,}"
    current=$((processed + 1))

    echo "[$current/$total] Processing: $filename"

    case "$extension" in
        jpg|jpeg)
            output="$OUTPUT_DIR/${base}-cvt.jpg"
            temp="$OUTPUT_DIR/${base}-cvt.tmp.jpg"

            if [[ -f "$output" ]]; then
                touch -r "$file" "$output"
                echo "Skipping existing photo; timestamp synchronized."
                skipped=$((skipped + 1))

            elif "$IMAGE_TOOL" "$file" \
                -quality "$PHOTO_QUALITY" \
                -define jpeg:optimize-coding=true \
                "$temp"
            then
                mv -- "$temp" "$output"
                touch -r "$file" "$output"

                echo "Completed: $(du -h "$output" | cut -f1)"
                successful=$((successful + 1))
            else
                rm -f -- "$temp"
                echo "Failed: $filename" >&2
                failed=$((failed + 1))
            fi
            ;;

        mp4)
            output="$OUTPUT_DIR/${base}-cvt.mp4"
            temp="$OUTPUT_DIR/${base}-cvt.tmp.mp4"

            if [[ -f "$output" ]]; then
                if ! sync_mp4_timestamps "$file" "$output"; then
                    timestamp_warnings=$((timestamp_warnings + 1))
                fi

                echo "Skipping existing video; timestamps synchronized."
                skipped=$((skipped + 1))

            elif ffmpeg -hide_banner -nostdin -i "$file" \
                -map_metadata 0 \
                -c:v libx265 -preset ultrafast -crf 28 \
                -c:a aac -b:a 250k \
                -y "$temp"
            then
                mv -- "$temp" "$output"

                if ! sync_mp4_timestamps "$file" "$output"; then
                    timestamp_warnings=$((timestamp_warnings + 1))
                fi

                echo "Completed: $(du -h "$output" | cut -f1)"
                successful=$((successful + 1))
            else
                rm -f -- "$temp"
                echo "Failed: $filename" >&2
                failed=$((failed + 1))
            fi
            ;;
    esac

    processed=$((processed + 1))
    pending=$((total - processed))

    echo "Progress: Processed $processed/$total | Pending: $pending"
    echo
done

echo "Processing summary:"
echo "  Total:              $total"
echo "  Successful:         $successful"
echo "  Skipped:            $skipped"
echo "  Failed:             $failed"
echo "  Timestamp warnings: $timestamp_warnings"
echo "  Pending:            0"
echo "  Output:             $OUTPUT_DIR"

if ((failed > 0)); then
    exit 1
fi
