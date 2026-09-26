#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

VERSION="$(cat VERSION | tr -d '[:space:]')"
echo "==> Preparing release v${VERSION}..."

echo "==> Running tests..."
swift test

echo "==> Building application bundle..."
"${SCRIPT_DIR}/build-app.sh"

echo "==> Creating DMG package..."
"${SCRIPT_DIR}/make-dmg.sh"

DMG_FILE="dist/QdrantBar-${VERSION}.dmg"
if [[ -f "${DMG_FILE}" ]]; then
    echo "==> Release build succeeded!"
    echo "    DMG: ${DMG_FILE}"
    echo "    SHA256: $(shasum -a 256 "${DMG_FILE}" | cut -d ' ' -f 1)"
fi
