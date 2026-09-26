# Contributing to QdrantBar

Thank you for your interest in contributing to QdrantBar!

## Principles

1. **Zero External Dependencies**: QdrantBar relies exclusively on Apple's native frameworks and Swift standard library.
2. **Separation of Concerns**: `QdrantBarCore` must remain free of UI/AppKit imports so it remains fully unit-testable.
3. **Safety First**: QdrantBar is monitor-only. Destructive operations (dropping collections, deleting points) and server management (start, stop, restart) are not supported.
4. **Localhost Only by Default**: Remote URLs are strictly opt-in, and credentials never leave the user's host.

## Development Setup

```bash
# Clone the repository
git clone https://github.com/fr3on/qdrantbar.git
cd qdrantbar

# Build and test
swift build
swift test

# Build application bundle
./scripts/build-app.sh
```

## Pull Request Guidelines

- Ensure `swift test` passes without any warnings.
- Keep commits small, focused, and descriptive.
- Do not include automated AI co-authorship attribution in commits or PR messages.

## Releasing

Maintainers publish a release by pushing a version tag:

1. Set the new number in `VERSION`, and add a dated `## [x.y.z]` section to `CHANGELOG.md`.
2. Commit, then tag and push: `git tag vX.Y.Z && git push origin main vX.Y.Z`.
3. The Release workflow checks that the tag matches `VERSION`, runs the tests, builds the DMG and creates a **draft** release with the DMG, `SHA256SUMS.txt` and notes taken from the changelog. A tag with a hyphen (for example `v0.2.0-beta.1`) is marked as a prerelease.
4. Review the draft on the Releases page and publish it.

The DMG is ad-hoc signed, not notarized. `./scripts/release-notes.sh <version>` previews the notes locally.
