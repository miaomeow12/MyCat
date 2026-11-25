#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
xcrun swiftc -swift-version 5 -O -module-cache-path "$ROOT/build/test-module-cache" \
  "$ROOT/Sources/MyCat/InputMotion.swift" "$ROOT/Sources/MyCat/PetLibrary.swift" "$ROOT/Tests/main.swift" -o "$ROOT/build/motion-tests"
"$ROOT/build/motion-tests"
if [[ "${1:-}" == "--ui" ]]; then
  "$ROOT/scripts/build.sh"
  APP="$ROOT/build/MyCat.app/Contents/MacOS/MyCat"
  CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mycat-checks.XXXXXX")"
  trap 'rm -rf "$CHECK_DIR"' EXIT
  "$APP" --input-test
  "$APP" --self-test "$CHECK_DIR"
  "$APP" --interaction-test
  "$APP" --pets-ui-test
  "$APP" --companion-test "$CHECK_DIR"
  "$APP" --export-generic-atlas "$CHECK_DIR/generic-atlas.png"
  "$APP" --generation-test "$CHECK_DIR/generic-atlas.png"
  "$APP" --generation-ui-test "$CHECK_DIR/generation-window.png"
  "$APP" --popup-test
fi
