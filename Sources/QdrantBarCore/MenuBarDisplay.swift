import Foundation

/// What the menu bar item should show, decided away from any drawing code so it can be tested.
public struct MenuBarDisplay: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case online, degraded, unauthorized, offline
    }

    public let state: State
    /// Text after the icon, or nil for icon only.
    public let text: String?
    public let tooltip: String

    public init(state: State, text: String?, tooltip: String) {
        self.state = state
        self.text = text
        self.tooltip = tooltip
    }

    public struct Input: Sendable {
        public var connection: ConnectionState
        public var hasDegradedCollections: Bool
        public var totalPoints: Int
        public var latencyMs: Double?
        public var collectionCount: Int
        public var serverName: String

        public init(
            connection: ConnectionState,
            hasDegradedCollections: Bool = false,
            totalPoints: Int = 0,
            latencyMs: Double? = nil,
            collectionCount: Int = 0,
            serverName: String = ""
        ) {
            self.connection = connection
            self.hasDegradedCollections = hasDegradedCollections
            self.totalPoints = totalPoints
            self.latencyMs = latencyMs
            self.collectionCount = collectionCount
            self.serverName = serverName
        }
    }

    public static func make(_ input: Input, settings: AppSettings) -> MenuBarDisplay {
        let state: State
        switch input.connection {
        case .offline: state = .offline
        case .unauthorized: state = .unauthorized
        case .online: state = input.hasDegradedCollections ? .degraded : .online
        }

        let text: String?
        switch state {
        case .offline:
            text = settings.menuBarStat == .none || settings.hideStatWhenOffline ? nil : "off"
        case .unauthorized:
            text = settings.menuBarStat == .none ? nil : "key"
        case .online, .degraded:
            switch settings.menuBarStat {
            case .none: text = nil
            case .points: text = compactCount(input.totalPoints)
            case .latency: text = input.latencyMs.map { "\(Int($0.rounded())) ms" }
            case .collections: text = "\(input.collectionCount)"
            }
        }

        return MenuBarDisplay(state: state, text: text, tooltip: tooltip(input, state: state))
    }

    /// 950 -> "950", 3300 -> "3.3k", 1_714_998 -> "1.7M"
    public static func compactCount(_ value: Int) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...: return String(format: "%.1fk", Double(value) / 1_000)
        default: return "\(value)"
        }
    }

    private static func tooltip(_ input: Input, state: State) -> String {
        var parts = ["QdrantBar"]
        if !input.serverName.isEmpty { parts.append(input.serverName) }
        switch state {
        case .online: parts.append("Online")
        case .degraded: parts.append("Degraded")
        case .unauthorized: parts.append("Needs API key")
        case .offline: parts.append("Offline")
        }
        if state == .online || state == .degraded {
            parts.append("\(input.totalPoints) points")
            if let latency = input.latencyMs { parts.append("\(Int(latency.rounded())) ms") }
        }
        return parts.joined(separator: " · ")
    }
}
