#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/MyCat.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/ASSET_LICENSE.md" "$APP/Contents/Resources/ASSET_LICENSE.md"
# The private edition may include the owner's explicitly authorized Q-version atlas.
if [[ -f "$ROOT/Resources/personal-cat.png" ]]; then
  cp "$ROOT/Resources/personal-cat.png" "$APP/Contents/Resources/"
else
  rm -f "$APP/Contents/Resources/personal-cat.png"
fi
SDK="$(xcrun --sdk macosx --show-sdk-path)"
if [[ "${1:-}" == "--universal" ]]; then
  for ARCH in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$ARCH-apple-macosx14.0" \
      -module-cache-path "$BUILD/module-cache-$ARCH" "$ROOT"/Sources/MyCat/*.swift -o "$BUILD/MyCat-$ARCH"
  done
  xcrun lipo -create "$BUILD/MyCat-arm64" "$BUILD/MyCat-x86_64" -output "$APP/Contents/MacOS/MyCat"
else
  ARCH="$(uname -m)"
  xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$ARCH-apple-macosx14.0" \
    -module-cache-path "$BUILD/module-cache-$ARCH" "$ROOT"/Sources/MyCat/*.swift -o "$APP/Contents/MacOS/MyCat"
fi
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf 'Built %s\n' "$APP"
