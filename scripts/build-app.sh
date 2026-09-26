#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

VERSION="$(cat VERSION | tr -d '[:space:]')"
echo "==> Building QdrantBar v${VERSION}..."

BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/QdrantBar.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "==> Compiling Swift release build..."
swift build -c release --arch arm64 --arch x86_64 2>/dev/null || swift build -c release

RELEASE_BIN="${ROOT_DIR}/.build/apple/Products/Release/QdrantBar"
if [[ ! -f "${RELEASE_BIN}" ]]; then
    RELEASE_BIN="${ROOT_DIR}/.build/release/QdrantBar"
fi

if [[ ! -f "${RELEASE_BIN}" ]]; then
    echo "Error: Release binary not found at ${RELEASE_BIN}"
    exit 1
fi

cp "${RELEASE_BIN}" "${MACOS_DIR}/QdrantBar"
chmod +x "${MACOS_DIR}/QdrantBar"

if [[ -f "${ROOT_DIR}/assets/AppIcon.icns" ]]; then
    cp "${ROOT_DIR}/assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
else
    echo "Warning: assets/AppIcon.icns is missing; run scripts/make-icon.sh. The app will show a generic icon."
fi

echo "==> Generating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleName</key>
    <string>QdrantBar</string>
    <key>CFBundleDisplayName</key>
    <string>QdrantBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.0x200.qdrantbar</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>QdrantBar</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <!-- macOS blocks remote http:// by default. This lifts the blanket block so a user can allow one
             server at a time; QdrantBarCore.ConnectionPolicy refuses remote http:// unless that server's
             profile opts in. -->
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Successfully created ${APP_BUNDLE}"
