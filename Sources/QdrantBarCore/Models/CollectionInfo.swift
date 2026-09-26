import Foundation

public enum CollectionStatus: String, Codable, Sendable, Equatable {
    case green
    case yellow
    case grey
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).lowercased()
        self = CollectionStatus(rawValue: raw) ?? .unknown
    }
}

public enum DistanceMetric: String, Codable, Sendable, Equatable {
    case cosine = "Cosine"
    case dot = "Dot"
    case euclid = "Euclid"
    case manhattan = "Manhattan"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = DistanceMetric(rawValue: raw) ?? .unknown
    }
}

public struct HnswConfig: Codable, Sendable, Equatable {
    public let m: Int?
    public let efConstruct: Int?
    public let fullScanThreshold: Int?
    public let onDisk: Bool?

    enum CodingKeys: String, CodingKey {
        case m
        case efConstruct = "ef_construct"
        case fullScanThreshold = "full_scan_threshold"
        case onDisk = "on_disk"
    }

    public init(m: Int? = nil, efConstruct: Int? = nil, fullScanThreshold: Int? = nil, onDisk: Bool? = nil) {
        self.m = m
        self.efConstruct = efConstruct
        self.fullScanThreshold = fullScanThreshold
        self.onDisk = onDisk
    }
}

/// Only the kind of quantization is kept ("scalar", "product", "binary"); its tuning is not shown.
public struct QuantizationInfo: Codable, Sendable, Equatable {
    public let kind: String

    public init(kind: String) {
        self.kind = kind
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        kind = container.allKeys.first?.stringValue ?? "unknown"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode([kind: [String: String]()])
    }
}

public struct VectorParams: Codable, Sendable, Equatable {
    public let size: Int?
    public let distance: DistanceMetric?
    public let onDisk: Bool?
    public let hnswConfig: HnswConfig?
    public let quantizationConfig: QuantizationInfo?

    enum CodingKeys: String, CodingKey {
        case size
        case distance
        case onDisk = "on_disk"
        case hnswConfig = "hnsw_config"
        case quantizationConfig = "quantization_config"
    }

    public init(
        size: Int?,
        distance: DistanceMetric?,
        onDisk: Bool? = nil,
        hnswConfig: HnswConfig? = nil,
        quantizationConfig: QuantizationInfo? = nil
    ) {
        self.size = size
        self.distance = distance
        self.onDisk = onDisk
        self.hnswConfig = hnswConfig
        self.quantizationConfig = quantizationConfig
    }
}

public enum VectorsConfig: Codable, Sendable, Equatable {
    case single(VectorParams)
    case multiple([String: VectorParams])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let multi = try? container.decode([String: VectorParams].self), !multi.isEmpty {
            self = .multiple(multi)
            return
        }
        if let single = try? container.decode(VectorParams.self), single.size != nil || single.distance != nil {
            self = .single(single)
            return
        }
        self = .multiple([:])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .single(params):
            try container.encode(params)
        case let .multiple(dict):
            try container.encode(dict)
        }
    }
}

/// Sparse vectors are listed by name only; their tuning is not shown.
public struct SparseVectorParams: Codable, Sendable, Equatable {
    public init() {}
}

public struct CollectionParams: Codable, Sendable, Equatable {
    public let vectors: VectorsConfig?
    public let sparseVectors: [String: SparseVectorParams]?
    public let shardNumber: Int?
    public let replicationFactor: Int?
    public let writeConsistencyFactor: Int?
    public let onDiskPayload: Bool?

    enum CodingKeys: String, CodingKey {
        case vectors
        case sparseVectors = "sparse_vectors"
        case shardNumber = "shard_number"
        case replicationFactor = "replication_factor"
        case writeConsistencyFactor = "write_consistency_factor"
        case onDiskPayload = "on_disk_payload"
    }

    public init(
        vectors: VectorsConfig? = nil,
        sparseVectors: [String: SparseVectorParams]? = nil,
        shardNumber: Int? = nil,
        replicationFactor: Int? = nil,
        writeConsistencyFactor: Int? = nil,
        onDiskPayload: Bool? = nil
    ) {
        self.vectors = vectors
        self.sparseVectors = sparseVectors
        self.shardNumber = shardNumber
        self.replicationFactor = replicationFactor
        self.writeConsistencyFactor = writeConsistencyFactor
        self.onDiskPayload = onDiskPayload
    }
}

public struct OptimizerConfig: Codable, Sendable, Equatable {
    public let indexingThreshold: Int?

    enum CodingKeys: String, CodingKey {
        case indexingThreshold = "indexing_threshold"
    }

    public init(indexingThreshold: Int? = nil) {
        self.indexingThreshold = indexingThreshold
    }
}

public struct CollectionConfig: Codable, Sendable, Equatable {
    public let params: CollectionParams?
    public let hnswConfig: HnswConfig?
    public let optimizerConfig: OptimizerConfig?
    public let quantizationConfig: QuantizationInfo?

    enum CodingKeys: String, CodingKey {
        case params
        case hnswConfig = "hnsw_config"
        case optimizerConfig = "optimizer_config"
        case quantizationConfig = "quantization_config"
    }

    public init(
        params: CollectionParams? = nil,
        hnswConfig: HnswConfig? = nil,
        optimizerConfig: OptimizerConfig? = nil,
        quantizationConfig: QuantizationInfo? = nil
    ) {
        self.params = params
        self.hnswConfig = hnswConfig
        self.optimizerConfig = optimizerConfig
        self.quantizationConfig = quantizationConfig
    }
}

/// Qdrant reports `"ok"`, or an object such as `{"error": "..."}`. Both must decode.
public struct OptimizerStatus: Codable, Sendable, Equatable, ExpressibleByStringLiteral {
    public let isOk: Bool
    public let message: String?

    public init(isOk: Bool, message: String? = nil) {
        self.isOk = isOk
        self.message = message
    }

    public init(stringLiteral value: String) {
        self.init(isOk: value.lowercased() == "ok", message: value.lowercased() == "ok" ? nil : value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = OptimizerStatus(stringLiteral: text)
        } else if let object = try? container.decode([String: String].self) {
            self = OptimizerStatus(isOk: false, message: object.values.first)
        } else {
            self = OptimizerStatus(isOk: false, message: nil)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isOk ? "ok" : (message ?? "error"))
    }
}

public struct PayloadIndexInfo: Codable, Sendable, Equatable {
    public let dataType: String
    public let points: Int?

    enum CodingKeys: String, CodingKey {
        case dataType = "data_type"
        case points
    }

    public init(dataType: String, points: Int? = nil) {
        self.dataType = dataType
        self.points = points
    }
}

public struct UpdateQueue: Codable, Sendable, Equatable {
    public let length: Int?

    public init(length: Int? = nil) {
        self.length = length
    }
}

public struct CollectionDetail: Codable, Sendable, Equatable {
    public let status: CollectionStatus
    public let optimizerStatus: OptimizerStatus?
    public let vectorsCount: Int?
    public let indexedVectorsCount: Int?
    public let pointsCount: Int?
    public let segmentsCount: Int?
    public let config: CollectionConfig?
    public let payloadSchema: [String: PayloadIndexInfo]?
    public let updateQueue: UpdateQueue?

    enum CodingKeys: String, CodingKey {
        case status
        case optimizerStatus = "optimizer_status"
        case vectorsCount = "vectors_count"
        case indexedVectorsCount = "indexed_vectors_count"
        case pointsCount = "points_count"
        case segmentsCount = "segments_count"
        case config
        case payloadSchema = "payload_schema"
        case updateQueue = "update_queue"
    }

    public init(
        status: CollectionStatus,
        optimizerStatus: OptimizerStatus? = nil,
        vectorsCount: Int? = nil,
        indexedVectorsCount: Int? = nil,
        pointsCount: Int? = nil,
        segmentsCount: Int? = nil,
        config: CollectionConfig? = nil,
        payloadSchema: [String: PayloadIndexInfo]? = nil,
        updateQueue: UpdateQueue? = nil
    ) {
        self.status = status
        self.optimizerStatus = optimizerStatus
        self.vectorsCount = vectorsCount
        self.indexedVectorsCount = indexedVectorsCount
        self.pointsCount = pointsCount
        self.segmentsCount = segmentsCount
        self.config = config
        self.payloadSchema = payloadSchema
        self.updateQueue = updateQueue
    }
}

public struct CollectionSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct CollectionsListResult: Codable, Sendable, Equatable {
    public let collections: [CollectionSummary]

    public init(collections: [CollectionSummary]) {
        self.collections = collections
    }
}

public struct CollectionItem: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public var detail: CollectionDetail?
    public var isLoading: Bool

    public init(name: String, detail: CollectionDetail? = nil, isLoading: Bool = false) {
        self.name = name
        self.detail = detail
        self.isLoading = isLoading
    }

    public var status: CollectionStatus {
        detail?.status ?? .unknown
    }

    public var pointsCount: Int {
        detail?.pointsCount ?? 0
    }

    public var vectorsCount: Int {
        if let count = detail?.vectorsCount, count > 0 {
            return count
        }
        if let config = detail?.config?.params?.vectors {
            switch config {
            case .single:
                return pointsCount
            case let .multiple(dict):
                return pointsCount * max(1, dict.count)
            }
        }
        return pointsCount
    }

    public var vectorDimensionsSummary: String {
        guard let config = detail?.config?.params?.vectors else { return "-" }
        switch config {
        case let .single(params):
            if let size = params.size {
                let dist = params.distance?.rawValue ?? ""
                return dist.isEmpty ? "\(size)d" : "\(size)d (\(dist))"
            }
            return "-"
        case let .multiple(dict):
            let count = dict.count
            return "\(count) vector\(count == 1 ? "" : "s")"
        }
    }
}
