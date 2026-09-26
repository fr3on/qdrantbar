# Roadmap

Where QdrantBar is heading after 0.1.0. This is a direction, not a promise: there are no dates, and the order can change as people use the app. Ideas and votes are welcome in [issues](https://github.com/fr3on/qdrantbar/issues).

QdrantBar stays **small, read-only and private**. Everything below fits that.

Sizes are rough effort: **S** is a day or less, **M** a few days, **L** about a week or more.

## 0.2.0: easier to manage, and it tells you when something changes

Tracked in the [v0.2.0 milestone](https://github.com/fr3on/qdrantbar/milestone/1).

| Item | Why | Size |
| :--- | :--- | :--- |
| [**Edit a server**](https://github.com/fr3on/qdrantbar/issues/1) (name, URL, environment, API key, insecure HTTP) | Today a server can only be added or deleted, so changing a key means re-adding it. | M |
| [**Keyboard shortcuts that work in the popover**](https://github.com/fr3on/qdrantbar/issues/2): `⌘F` filter, `⌘R` refresh, `Esc` clear, `⌘,` Settings | Only `⌘,` and `⌘Q` exist, and only while the gear menu is open. | M |
| [**Check for updates**](https://github.com/fr3on/qdrantbar/issues/3) in Settings | One request to the GitHub Releases API, sent only when you press the button. | S |
| [**Notifications**](https://github.com/fr3on/qdrantbar/issues/4), off by default and per server | Tell me when the server goes offline or returns, a collection is not green, or the optimizer reports an error. Debounced so a flapping server does not spam. | M |
| [**Lighter refresh for large servers**](https://github.com/fr3on/qdrantbar/issues/5) | Every refresh currently requests details for every collection. Load them lazily and cap concurrency so a server with hundreds of collections stays cheap. | M |
| [**Reliability and tests**](https://github.com/fr3on/qdrantbar/issues/6) | Fix the Keychain save race in Add Server, and move refresh and server-switching logic out of the 700-line `AppState` into Core types that can be unit tested. Only Core has tests today. | M |

## 0.3.0: more depth

| Item | Why | Size |
| :--- | :--- | :--- |
| **Memory view** (RAM and disk by component) | The Qdrant dashboard's most useful screen for big collections. First confirm which telemetry fields carry it on real servers, and on which versions. | M |
| **Cluster view** for distributed deployments (peers, shards, transfers) | Shown only when distributed mode is on, hidden otherwise. | M |
| **All servers at a glance** | A status dot per server in the list, and the worst state in the menu bar. | M |
| **Short history** | Keep the last hours of points and latency so the sparkline survives a restart. | M |
| **Signed and notarized builds, and a Homebrew cask** | Removes the "Open Anyway" step. Needs an Apple Developer account. | M |

## Later

Ideas that are not scheduled: a Prometheus `/metrics` view, localization, a VoiceOver and reduced-motion pass, a macOS widget, a DMG background and volume icon, and a vector logo.

## Not planned

- **Anything that changes a server:** starting or stopping it, deleting data, creating snapshots or triggering the optimizer. Those stay in the Qdrant dashboard, one click away.
- **Analytics or telemetry.**
- **Third-party dependencies.** This rules out update frameworks such as Sparkle, which is why updates are a manual check.
- **Other platforms.** QdrantBar is a native macOS app.

## Contributing to the roadmap

Open an issue describing the problem you want solved. Read [CONTRIBUTING.md](CONTRIBUTING.md) first, and note the rules above: a change that writes to a server or adds a dependency is unlikely to be accepted.
