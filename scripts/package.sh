#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh" --universal
mkdir -p "$ROOT/dist"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/MyCat.app" "$ROOT/dist/MyCat-macOS-universal.zip"
(cd "$ROOT/dist" && shasum -a 256 MyCat-macOS-universal.zip > SHA256SUMS.txt)
printf 'Packaged %s/dist/MyCat-macOS-universal.zip\n' "$ROOT"
