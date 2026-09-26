## What and why

<!-- What does this change, and what problem does it solve? Link the issue if there is one. -->

## Checklist

- [ ] `swift build` and `swift test` pass
- [ ] Core changes have tests (new Qdrant response shapes include a fixture)
- [ ] Read-only: only `GET` requests, and nothing that changes a server or its data
- [ ] Text from a server (collection names and so on) is treated as untrusted before it reaches the clipboard or a command
- [ ] Remote `http://` stays gated by `ConnectionPolicy`
- [ ] No new dependencies, and no network calls except to servers the user added
- [ ] UI changes include a screenshot
- [ ] `CHANGELOG.md` updated for user-visible changes

## Screenshots

<!-- Before / after, if the UI changed. -->
