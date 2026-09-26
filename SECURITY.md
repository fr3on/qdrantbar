# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | Yes |

## Security Features

- **No Remote Telemetry**: QdrantBar does not collect, track, or phone home any telemetry, analytics, or user identifiers.
- **Localhost Default**: Defaults strictly to `http://localhost:6333`. Remote connections require explicit user input.
- **Encrypted by default**: Remote servers should use `https://`. A remote `http://` server (anything that is not loopback, LAN and VPN addresses included) is refused before any request is sent, unless that server's profile has **Allow insecure HTTP** switched on. The switch is per server and off by default. The API key and data travel unencrypted on such a connection, so use https or an SSH tunnel (`ssh -N -L 6333:localhost:6333 user@host`) where you can.
- **Why App Transport Security is off**: macOS blocks remote `http://` for the whole app unless `NSAllowsArbitraryLoads` is set, and it cannot be relaxed per host at run time. The app sets it so the per-server opt-in can work, and enforces the rule itself in `QdrantBarCore.ConnectionPolicy` (tested), so the effective behavior stays "https or opted-in".
- **Keychain Storage**: API keys are securely persisted in the Apple Keychain using `kSecClassGenericPassword` with `kSecAttrAccessibleAfterFirstUnlock`. Keys are sent only in HTTP requests to the user's explicitly configured host.
- **Read-only**: QdrantBar sends only `GET` requests. It never starts, stops or signals a process, and never changes data on a server.

## Reporting a Vulnerability

If you discover a security vulnerability in QdrantBar, please report it privately via GitHub Security Advisories or by contacting the project maintainers directly.
