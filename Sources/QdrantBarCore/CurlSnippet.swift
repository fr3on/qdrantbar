import Foundation

public enum ShellQuote {
    /// POSIX single quoting: nothing inside is interpreted by the shell.
    public static func single(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum CurlSnippet {
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// A `curl` command for one collection. The name comes from the server, so it is percent-encoded
    /// and the whole URL is single-quoted before it can reach a shell.
    public static func collection(baseURL: String, name: String, apiKey: String?) -> String {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        let encoded = name.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
        var command = "curl -X GET \(ShellQuote.single("\(base)/collections/\(encoded)"))"
        if let apiKey, !apiKey.isEmpty {
            command += " -H \(ShellQuote.single("api-key: \(apiKey)"))"
        }
        return command
    }
}
