#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

VERSION="$(cat VERSION | tr -d '[:space:]')"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/QdrantBar.app"
DIST_DIR="${ROOT_DIR}/dist"
DMG_PATH="${DIST_DIR}/QdrantBar-${VERSION}.dmg"

if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "==> QdrantBar.app not found, building first..."
    "${SCRIPT_DIR}/build-app.sh"
fi

echo "==> Creating DMG at ${DMG_PATH}..."
mkdir -p "${DIST_DIR}"
rm -f "${DMG_PATH}"

TMP_DMG_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DMG_DIR}"' EXIT

cp -R "${APP_BUNDLE}" "${TMP_DMG_DIR}/"
ln -s /Applications "${TMP_DMG_DIR}/Applications"

hdiutil create -volname "QdrantBar" -srcfolder "${TMP_DMG_DIR}" -ov -format UDZO "${DMG_PATH}"

echo "==> Created ${DMG_PATH}"
