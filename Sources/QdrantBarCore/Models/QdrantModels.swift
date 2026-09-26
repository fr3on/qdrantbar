import Foundation

public struct QdrantResponse<T: Codable & Sendable>: Codable, Sendable {
    public let time: Double?
    public let status: String
    public let result: T

    public init(time: Double? = nil, status: String = "ok", result: T) {
        self.time = time
        self.status = status
        self.result = result
    }
}

public struct QdrantVersion: Codable, Sendable, Equatable {
    public let title: String
    public let version: String
    public let commit: String?

    public init(title: String, version: String, commit: String? = nil) {
        self.title = title
        self.version = version
        self.commit = commit
    }
}

public struct HealthResponse: Codable, Sendable, Equatable {
    public let title: String?
    public let version: String?
    public let commit: String?
    public let status: String?

    public init(title: String? = nil, version: String? = nil, commit: String? = nil, status: String? = nil) {
        self.title = title
        self.version = version
        self.commit = commit
        self.status = status
    }

    public var isHealthy: Bool {
        if let status, status.lowercased() == "ok" {
            return true
        }
        if title != nil || version != nil {
            return true
        }
        return false
    }
}

public struct TelemetryApp: Codable, Sendable, Equatable {
    public let version: String?
    public let name: String?

    public init(version: String? = nil, name: String? = nil) {
        self.version = version
        self.name = name
    }
}

public struct TelemetryInfo: Codable, Sendable, Equatable {
    public let id: String?
    public let app: TelemetryApp?
    public let collectionsCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case app
        case collectionsCount = "collections_count"
    }

    public init(id: String? = nil, app: TelemetryApp? = nil, collectionsCount: Int? = nil) {
        self.id = id
        self.app = app
        self.collectionsCount = collectionsCount
    }
}
