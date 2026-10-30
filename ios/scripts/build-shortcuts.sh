#!/bin/sh
# Compiles and signs the Shortcuts in shortcuts/*.cherri with the Cherri
# command-line tool (https://github.com/electrikmilk/cherri, GPL-2.0, used
# as a build tool only). Signing runs Apple's `shortcuts sign`, so this
# needs macOS; iOS rejects unsigned shortcuts.
#
# Writes shortcuts/dist/<name>.shortcut for each source, plus manifest.json
# (name, file, sha256, version). Fails if any output isn't signed.
#
# Usage: scripts/build-shortcuts.sh [output-dir]   (default: shortcuts/dist)
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$root/shortcuts/dist}"

if [ "$(uname -s)" != Darwin ]; then
    echo "Signing Shortcuts needs macOS (Apple's 'shortcuts sign')." >&2
    exit 1
fi
if ! command -v cherri >/dev/null 2>&1; then
    echo "cherri isn't installed: brew install electrikmilk/cherri/cherri" >&2
    exit 1
fi

rm -rf "$out"
mkdir -p "$out"

version="$(cherri --version | head -n 1)"
manifest="$out/manifest.json"
printf '{\n  "cherri": "%s",\n  "shortcuts": [' "$version" > "$manifest"

first=1
for source in "$root"/shortcuts/*.cherri; do
    stem="$(basename "$source" .cherri)"
    file="$stem.shortcut"
    cherri "$source" --share=anyone --output="$out/$file"

    # Signed shortcuts start with "AEA1"; an unsigned one is a binary plist.
    if [ "$(head -c 4 "$out/$file")" != AEA1 ]; then
        echo "$file isn't signed (does 'shortcuts sign' work on this Mac?)" >&2
        exit 1
    fi

    [ "$first" = 1 ] || printf ',' >> "$manifest"
    first=0
    printf '\n    {"name": "%s", "file": "%s", "sha256": "%s"}' \
        "$stem" "$file" "$(shasum -a 256 "$out/$file" | cut -d ' ' -f 1)" >> "$manifest"
done

printf '\n  ]\n}\n' >> "$manifest"
echo "built $(ls "$out"/*.shortcut | wc -l | tr -d ' ') shortcut(s) in $out"
