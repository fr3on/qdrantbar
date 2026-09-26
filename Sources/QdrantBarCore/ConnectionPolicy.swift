import Foundation

/// Which servers may be reached over plain `http://`.
///
/// macOS blocks unencrypted requests to remote hosts (App Transport Security). The app turns that
/// blanket block off in its `Info.plist` so a user can opt in per server, and this policy is what
/// keeps the default safe: a remote `http://` server is refused unless its profile allows it.
public enum ConnectionPolicy {
    /// Loopback only. A LAN address is remote as far as encryption goes.
    public static func isLoopback(host: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return host == "localhost" || host == "::1" || host.hasSuffix(".localhost") || host == "127.0.0.1" || host.hasPrefix("127.")
    }

    /// True for `http://` to anything that is not loopback: such a server needs an explicit opt-in.
    public static func requiresInsecureOptIn(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "http", let host = url.host, !host.isEmpty else { return false }
        return !isLoopback(host: host)
    }

    public static func requiresInsecureOptIn(_ urlString: String) -> Bool {
        URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)).map(requiresInsecureOptIn) ?? false
    }
}
