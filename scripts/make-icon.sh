#!/bin/zsh
# Draws the artwork and builds assets/AppIcon.icns. Re-run whenever scripts/make-icon.swift changes.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets

TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

swift scripts/make-icon.swift assets/icon_1024.png assets/logo.png
for size in 16 32 128 256 512; do
  sips -z $size $size assets/icon_1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) assets/icon_1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o assets/AppIcon.icns
rm -rf "$TMP"
echo "Wrote assets/icon_1024.png, assets/logo.png and assets/AppIcon.icns"
