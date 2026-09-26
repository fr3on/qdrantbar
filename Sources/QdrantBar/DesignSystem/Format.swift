import Foundation

enum Format {
    /// 3300 -> "3,300"
    static func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// 3300 -> "3.3k", 1_250_000 -> "1.3M"
    static func compact(_ value: Int) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...: return String(format: "%.1fk", Double(value) / 1_000)
        default: return "\(value)"
        }
    }

    /// Exact below a million, "1.71M" above, so a hero number never overflows.
    static func points(_ value: Int) -> String {
        value >= 1_000_000 ? String(format: "%.2fM", Double(value) / 1_000_000) : count(value)
    }

    /// "http://localhost:6333/" -> "localhost:6333"
    static func host(_ urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else { return urlString }
        return url.port.map { "\(host):\($0)" } ?? host
    }
}
