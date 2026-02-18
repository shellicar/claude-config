#!/bin/sh
# Export all .drawio files in the output directory to PNG.
set -e

if ! command -v drawio >/dev/null 2>&1; then
    echo "Error: drawio not found. See the azure-devops-boards skill for install instructions." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../output"

count=0
for f in "$OUTPUT_DIR"/*.drawio; do
    [ -f "$f" ] || continue
    png="${f%.drawio}.png"
    echo "Exporting $(basename "$f") -> $(basename "$png")"
    drawio --export --format png --output "$png" "$f" --disable-gpu --no-sandbox >/dev/null
    count=$((count + 1))
done

echo "Exported $count diagram(s)"
