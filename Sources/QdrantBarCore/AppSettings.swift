import Foundation

/// User preferences that are not tied to one server. Stored as one JSON blob in UserDefaults.
public struct AppSettings: Codable, Sendable, Equatable {
    public enum MenuBarStat: String, Codable, CaseIterable, Sendable, Identifiable {
        case none, points, latency, collections

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .none: return "Icon only"
            case .points: return "Points"
            case .latency: return "Latency"
            case .collections: return "Collections"
            }
        }
    }

    public static let openRefreshChoices = [5, 10, 30]
    /// 0 turns the background check off.
    public static let backgroundRefreshChoices = [0, 30, 60, 300]
    public static let storageKey = "qdrantbar_settings"

    public var menuBarStat: MenuBarStat
    /// Show only the icon and dot while the server is unreachable, instead of "off".
    public var hideStatWhenOffline: Bool
    public var openRefreshSeconds: Int
    public var backgroundRefreshSeconds: Int

    public init(
        menuBarStat: MenuBarStat = .points,
        hideStatWhenOffline: Bool = true,
        openRefreshSeconds: Int = 10,
        backgroundRefreshSeconds: Int = 30
    ) {
        self.menuBarStat = menuBarStat
        self.hideStatWhenOffline = hideStatWhenOffline
        self.openRefreshSeconds = openRefreshSeconds
        self.backgroundRefreshSeconds = backgroundRefreshSeconds
    }

    /// Any missing key falls back to its default, so a future or older blob never resets everything.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        menuBarStat = (try? container.decodeIfPresent(MenuBarStat.self, forKey: .menuBarStat)) ?? defaults.menuBarStat
        hideStatWhenOffline = try container.decodeIfPresent(Bool.self, forKey: .hideStatWhenOffline) ?? defaults.hideStatWhenOffline
        openRefreshSeconds = try container.decodeIfPresent(Int.self, forKey: .openRefreshSeconds) ?? defaults.openRefreshSeconds
        backgroundRefreshSeconds = try container.decodeIfPresent(Int.self, forKey: .backgroundRefreshSeconds) ?? defaults.backgroundRefreshSeconds
    }

    /// Snaps intervals to the offered choices, so a hand-edited value cannot hammer a server.
    public func normalized() -> AppSettings {
        var copy = self
        if !Self.openRefreshChoices.contains(copy.openRefreshSeconds) {
            copy.openRefreshSeconds = Self.openRefreshChoices.min { abs($0 - copy.openRefreshSeconds) < abs($1 - copy.openRefreshSeconds) } ?? 10
        }
        if !Self.backgroundRefreshChoices.contains(copy.backgroundRefreshSeconds) {
            copy.backgroundRefreshSeconds = Self.backgroundRefreshChoices.min { abs($0 - copy.backgroundRefreshSeconds) < abs($1 - copy.backgroundRefreshSeconds) } ?? 30
        }
        return copy
    }

    public static func load(from defaults: UserDefaults = .standard) -> AppSettings {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded.normalized()
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
