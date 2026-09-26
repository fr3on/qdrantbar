import Foundation

public enum IndexingState: Equatable, Sendable {
    /// No points yet.
    case empty
    /// Below the indexing threshold: searched exactly, so an index count of zero is normal.
    case exactScan(threshold: Int?)
    case building(Double)
    case indexed
}

public struct VectorRow: Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let spec: String
    public let notes: String
}

public struct KeyValueRow: Equatable, Sendable, Identifiable {
    public var id: String { label }
    public let label: String
    public let value: String
}

public struct PayloadIndexRow: Equatable, Sendable, Identifiable {
    public var id: String { field }
    public let field: String
    public let type: String
    public let points: Int?
}

public struct CollectionAttention: Equatable, Sendable {
    public let title: String
    public let body: String
    public let isError: Bool
}

/// Everything the detail screen shows for one collection. Sections that failed to load stay `nil`,
/// so the UI can say "unavailable" instead of claiming there are no aliases or snapshots.
public struct CollectionDetailBundle: Sendable, Equatable {
    public var name: String
    public var detail: CollectionDetail?
    public var aliases: [AliasDescription]?
    public var snapshots: [SnapshotDescription]?
    public var optimizations: OptimizationsInfo?
    public var rawJSON: String?
    public var isLoading: Bool
    public var errorMessage: String?

    public init(
        name: String,
        detail: CollectionDetail? = nil,
        aliases: [AliasDescription]? = nil,
        snapshots: [SnapshotDescription]? = nil,
        optimizations: OptimizationsInfo? = nil,
        rawJSON: String? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.name = name
        self.detail = detail
        self.aliases = aliases
        self.snapshots = snapshots
        self.optimizations = optimizations
        self.rawJSON = rawJSON
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    public var status: CollectionStatus { detail?.status ?? .unknown }
    public var pointsCount: Int { detail?.pointsCount ?? 0 }
    public var segmentsCount: Int { detail?.segmentsCount ?? 0 }
    public var updateQueueLength: Int { detail?.updateQueue?.length ?? 0 }

    private var params: CollectionParams? { detail?.config?.params }

    private var denseVectorCount: Int {
        switch params?.vectors {
        case .single, .none: return 1
        case let .multiple(dict): return dict.count
        }
    }

    private var vectorSlots: Int {
        pointsCount * max(1, denseVectorCount + (params?.sparseVectors?.count ?? 0))
    }

    public var runningOptimizations: Int { optimizations?.running.count ?? 0 }

    public var isOptimizing: Bool {
        runningOptimizations > 0 || (optimizations?.summary?.queuedOptimizations ?? 0) > 0
    }

    public var optimizerError: String? {
        guard let status = detail?.optimizerStatus, !status.isOk else { return nil }
        return status.message ?? "Unknown optimizer error"
    }

    public var indexing: IndexingState {
        guard pointsCount > 0 else { return .empty }
        let indexed = detail?.indexedVectorsCount ?? 0
        if indexed >= vectorSlots { return .indexed }
        if indexed == 0 && !isOptimizing {
            return .exactScan(threshold: detail?.config?.optimizerConfig?.indexingThreshold)
        }
        return .building(min(1, Double(indexed) / Double(max(vectorSlots, 1))))
    }

    /// Why the collection is not plain green, when there is something to say.
    public var attention: CollectionAttention? {
        if let message = optimizerError {
            return CollectionAttention(title: "Optimizer error", body: message, isError: true)
        }
        guard detail != nil, status != .green else { return nil }
        let title = status == .yellow ? "Yellow for now" : "Not ready"
        var body: String
        if isOptimizing {
            let queuedSegments = optimizations?.summary?.queuedSegments ?? 0
            var parts = [runningOptimizations == 1 ? "1 optimization running" : "\(runningOptimizations) optimizations running"]
            if queuedSegments > 0 { parts.append("\(queuedSegments) segments queued") }
            body = parts.joined(separator: ", ") + "."
        } else {
            body = "Qdrant reports \(status.rawValue) with no optimization running."
        }
        body += " It should return to green when background work finishes."
        return CollectionAttention(title: title, body: body, isError: false)
    }

    public var vectorRows: [VectorRow] {
        var rows: [VectorRow] = []
        switch params?.vectors {
        case let .single(vector):
            rows.append(row(name: "default", vector))
        case let .multiple(dict):
            rows += dict.keys.sorted().compactMap { key in dict[key].map { row(name: key, $0) } }
        case .none:
            break
        }
        if let sparse = params?.sparseVectors {
            rows += sparse.keys.sorted().map { VectorRow(name: $0, spec: "sparse", notes: "sparse index") }
        }
        return rows
    }

    private func row(name: String, _ vector: VectorParams) -> VectorRow {
        var spec = vector.size.map { "\($0)d" } ?? "?"
        if let distance = vector.distance, distance != .unknown { spec += " · \(distance.rawValue)" }
        var notes: [String] = []
        if vector.onDisk == true { notes.append("on disk") }
        if let hnsw = vector.hnswConfig ?? detail?.config?.hnswConfig, let m = hnsw.m {
            notes.append(hnsw.efConstruct.map { "HNSW m\(m) · ef \($0)" } ?? "HNSW m\(m)")
        }
        if let quantization = vector.quantizationConfig ?? detail?.config?.quantizationConfig {
            notes.append("\(quantization.kind) quantization")
        }
        return VectorRow(name: name, spec: spec, notes: notes.joined(separator: " · "))
    }

    public var storageRows: [KeyValueRow] {
        var rows: [KeyValueRow] = []
        if let value = params?.shardNumber { rows.append(KeyValueRow(label: "Shards", value: "\(value)")) }
        if let value = params?.replicationFactor { rows.append(KeyValueRow(label: "Replication factor", value: "\(value)")) }
        if let value = params?.writeConsistencyFactor { rows.append(KeyValueRow(label: "Write consistency", value: "\(value)")) }
        if let value = params?.onDiskPayload { rows.append(KeyValueRow(label: "Payload on disk", value: value ? "on" : "off")) }
        if let quantization = detail?.config?.quantizationConfig {
            rows.append(KeyValueRow(label: "Quantization", value: quantization.kind))
        }
        return rows
    }

    public var payloadIndexRows: [PayloadIndexRow] {
        (detail?.payloadSchema ?? [:])
            .map { PayloadIndexRow(field: $0.key, type: $0.value.dataType, points: $0.value.points) }
            .sorted { $0.field < $1.field }
    }

    /// Newest first; snapshots without a date go last.
    public var sortedSnapshots: [SnapshotDescription] {
        (snapshots ?? []).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    public var snapshotSummary: String {
        let list = snapshots ?? []
        guard !list.isEmpty else { return "No snapshots" }
        let total = list.reduce(Int64(0)) { $0 + $1.size }
        return "\(list.count) snapshot\(list.count == 1 ? "" : "s") · \(ByteSize.string(total))"
    }
}
