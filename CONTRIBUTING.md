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
