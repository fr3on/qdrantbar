import Foundation

public struct AliasDescription: Codable, Sendable, Equatable, Identifiable {
    public var id: String { aliasName }
    public let aliasName: String
    public let collectionName: String?

    enum CodingKeys: String, CodingKey {
        case aliasName = "alias_name"
        case collectionName = "collection_name"
    }

    public init(aliasName: String, collectionName: String? = nil) {
        self.aliasName = aliasName
        self.collectionName = collectionName
    }
}

public struct AliasesResult: Codable, Sendable, Equatable {
    public let aliases: [AliasDescription]

    public init(aliases: [AliasDescription]) {
        self.aliases = aliases
    }
}

public struct SnapshotDescription: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let creationTime: String?
    public let size: Int64

    enum CodingKeys: String, CodingKey {
        case name
        case creationTime = "creation_time"
        case size
    }

    public init(name: String, creationTime: String? = nil, size: Int64) {
        self.name = name
        self.creationTime = creationTime
        self.size = size
    }

    /// Qdrant sends UTC without a zone suffix, and may send nothing at all ("unknown" in its dashboard).
    public var createdAt: Date? {
        guard let creationTime else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: String(creationTime.prefix(19)))
    }
}

public struct OptimizationsSummary: Codable, Sendable, Equatable {
    public let queuedOptimizations: Int?
    public let queuedSegments: Int?
    public let queuedPoints: Int?
    public let idleSegments: Int?

    enum CodingKeys: String, CodingKey {
        case queuedOptimizations = "queued_optimizations"
        case queuedSegments = "queued_segments"
        case queuedPoints = "queued_points"
        case idleSegments = "idle_segments"
    }

    public init(queuedOptimizations: Int? = nil, queuedSegments: Int? = nil, queuedPoints: Int? = nil, idleSegments: Int? = nil) {
        self.queuedOptimizations = queuedOptimizations
        self.queuedSegments = queuedSegments
        self.queuedPoints = queuedPoints
        self.idleSegments = idleSegments
    }
}

/// Only the count of running optimizations is kept; their per-task details are not shown.
public struct RunningOptimization: Codable, Sendable, Equatable {
    public init() {}
}

public struct OptimizationsInfo: Codable, Sendable, Equatable {
    public let summary: OptimizationsSummary?
    public let running: [RunningOptimization]

    public init(summary: OptimizationsSummary? = nil, running: [RunningOptimization] = []) {
        self.summary = summary
        self.running = running
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(OptimizationsSummary.self, forKey: .summary)
        running = (try? container.decodeIfPresent([RunningOptimization].self, forKey: .running)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case summary
        case running
    }
}

public enum ByteSize {
    /// 10_951_393_280 -> "10.2 GB". Uses binary units, as Qdrant's dashboard does.
    public static func string(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(max(bytes, 0))
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        return unit == 0 ? "\(Int(value)) B" : String(format: "%.1f %@", value, units[unit])
    }
}
