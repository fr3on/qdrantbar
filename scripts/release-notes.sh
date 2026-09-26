#!/usr/bin/env bash
# Prints the GitHub release notes for a version: the matching CHANGELOG.md section, then install and
# checksum instructions. Used by .github/workflows/release.yml; safe to run locally.
#
#   ./scripts/release-notes.sh 0.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

VERSION="${1:?usage: release-notes.sh <version>}"

# The CHANGELOG section for this version: everything after "## [x.y.z]" up to the next "## [" heading.
CHANGES="$(awk -v v="${VERSION}" '
  index($0, "## [" v "]") == 1 { found = 1; next }
  found && index($0, "## [") == 1 { exit }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d')"

if [[ -z "$(printf '%s' "${CHANGES}" | tr -d '[:space:]')" ]]; then
    CHANGES="See [CHANGELOG.md](https://github.com/fr3on/qdrantbar/blob/main/CHANGELOG.md) for the changes in this release."
fi

cat <<NOTES
QdrantBar ${VERSION}: a small, native, read-only macOS menu bar app for watching a Qdrant server. It is an unofficial community tool and is not affiliated with Qdrant.

## Changes

${CHANGES}

## Install

1. Download \`QdrantBar-${VERSION}.dmg\`, open it and drag QdrantBar to Applications.
2. This build is ad-hoc signed and not notarized, so macOS blocks it the first time. Open **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to QdrantBar. Or remove the quarantine flag:

\`\`\`bash
xattr -dr com.apple.quarantine /Applications/QdrantBar.app
\`\`\`

QdrantBar has no Dock icon. Look for it in the menu bar. Requires macOS 14 or newer, on Apple silicon or Intel.

To avoid trusting a prebuilt binary, build it from source: see the README.

## Checksum

\`SHA256SUMS.txt\` is attached. Verify with:

\`\`\`bash
shasum -a 256 -c SHA256SUMS.txt
\`\`\`
NOTES
