import Foundation

public struct ServerProfile: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var urlString: String
    public var environmentTag: String
    /// Opt-in for a remote `http://` server. Has no effect on `https://` or loopback addresses.
    public var allowInsecureHTTP: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        environmentTag: String = "Development",
        allowInsecureHTTP: Bool = false
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.environmentTag = environmentTag
        self.allowInsecureHTTP = allowInsecureHTTP
    }

    /// Profiles saved before this option existed have no such key, and must load as "not allowed".
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        urlString = try container.decode(String.self, forKey: .urlString)
        environmentTag = try container.decode(String.self, forKey: .environmentTag)
        allowInsecureHTTP = try container.decodeIfPresent(Bool.self, forKey: .allowInsecureHTTP) ?? false
    }

    /// The URL is remote plain HTTP and this profile allows it.
    public var isInsecureRemote: Bool {
        allowInsecureHTTP && ConnectionPolicy.requiresInsecureOptIn(urlString)
    }

    public static let defaultLocal = ServerProfile(
        name: "Localhost",
        urlString: "http://localhost:6333",
        environmentTag: "Development"
    )
}
