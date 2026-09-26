import Foundation
import Testing
@testable import QdrantBarCore

@Suite("Collection detail")
struct CollectionDetailTests {
    private func fixture(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: try #require(url))
    }

    private func detail(_ name: String) throws -> CollectionDetail {
        try JSONDecoder().decode(QdrantResponse<CollectionDetail>.self, from: fixture(name)).result
    }

    @Test("A real small collection decodes, and zero indexed vectors is an exact scan, not a fault")
    func liveSmallCollection() throws {
        let d = try detail("collection_detail_live")
        #expect(d.status == .green)
        #expect(d.pointsCount == 2000)
        #expect(d.indexedVectorsCount == 0)
        #expect(d.optimizerStatus?.isOk == true)
        #expect(d.updateQueue?.length == 0)
        #expect(d.config?.params?.onDiskPayload == true)
        #expect(d.config?.hnswConfig?.m == 16)

        let bundle = CollectionDetailBundle(name: "docs", detail: d, optimizations: OptimizationsInfo(summary: nil, running: []))
        #expect(bundle.indexing == .exactScan(threshold: 10000))
        #expect(bundle.attention == nil)
        #expect(bundle.vectorRows == [VectorRow(name: "default", spec: "384d · Cosine", notes: "HNSW m16 · ef 100")])
        #expect(bundle.storageRows.map(\.label) == ["Shards", "Replication factor", "Write consistency", "Payload on disk"])
    }

    @Test("An optimizer error object no longer breaks decoding")
    func optimizerErrorObject() throws {
        let d = try detail("collection_detail_rich")
        #expect(d.optimizerStatus?.isOk == false)
        let bundle = CollectionDetailBundle(name: "articles", detail: d)
        #expect(bundle.optimizerError == "Service internal error: No space left on device")
        #expect(bundle.attention?.isError == true)
        #expect(bundle.attention?.title == "Optimizer error")
    }

    @Test("Rich collection: dense and sparse vectors, quantization, payload indexes, queue")
    func richCollection() throws {
        let bundle = CollectionDetailBundle(name: "articles", detail: try detail("collection_detail_rich"))
        #expect(bundle.vectorRows.map(\.name) == ["dense", "sparse"])
        #expect(bundle.vectorRows[0].spec == "1024d · Cosine")
        #expect(bundle.vectorRows[0].notes == "on disk · HNSW m16 · ef 100 · scalar quantization")
        #expect(bundle.vectorRows[1].spec == "sparse")
        #expect(bundle.payloadIndexRows.map(\.field) == ["doc_type", "year"])
        #expect(bundle.payloadIndexRows.last?.type == "integer")
        #expect(bundle.updateQueueLength == 1940)
        #expect(bundle.storageRows.contains(KeyValueRow(label: "Shards", value: "2")))
        // dense + sparse = two vector slots per point: 2.1M of 3.43M is partly built, not "indexed".
        if case let .building(fraction) = bundle.indexing { #expect(fraction > 0.6 && fraction < 0.62) } else { Issue.record("expected building") }
    }

    @Test("Indexed count above the slot count still reads as fully indexed")
    func indexedComplete() {
        let d = CollectionDetail(status: .green, optimizerStatus: "ok", indexedVectorsCount: 3_432_219, pointsCount: 1_714_998,
                                 config: CollectionConfig(params: CollectionParams(
                                    vectors: .single(VectorParams(size: 8, distance: .cosine)),
                                    sparseVectors: ["s": SparseVectorParams()])))
        #expect(CollectionDetailBundle(name: "x", detail: d).indexing == .indexed)
    }

    @Test("A yellow collection explains itself from the optimization queue")
    func yellowExplained() {
        let d = CollectionDetail(status: .yellow, optimizerStatus: "ok", indexedVectorsCount: 100, pointsCount: 1000)
        let info = OptimizationsInfo(summary: OptimizationsSummary(queuedOptimizations: 1, queuedSegments: 3), running: [RunningOptimization()])
        let attention = CollectionDetailBundle(name: "x", detail: d, optimizations: info).attention
        #expect(attention?.title == "Yellow for now")
        #expect(attention?.body.contains("1 optimization running, 3 segments queued.") == true)
        #expect(attention?.isError == false)
    }

    @Test("Empty collections and unknown sections")
    func emptyAndUnknown() {
        let empty = CollectionDetailBundle(name: "x", detail: CollectionDetail(status: .green, pointsCount: 0))
        #expect(empty.indexing == .empty)
        #expect(empty.snapshotSummary == "No snapshots")
        #expect(empty.aliases == nil)
    }

    @Test("Aliases, snapshots and optimizations decode")
    func extras() throws {
        let aliases = try JSONDecoder().decode(QdrantResponse<AliasesResult>.self, from: fixture("aliases_empty")).result
        #expect(aliases.aliases.isEmpty)

        let optimizations = try JSONDecoder().decode(QdrantResponse<OptimizationsInfo>.self, from: fixture("optimizations_idle")).result
        #expect(optimizations.running.isEmpty)
        #expect(optimizations.summary?.idleSegments == 5)

        let snapshots = try JSONDecoder().decode(QdrantResponse<[SnapshotDescription]>.self, from: fixture("snapshots")).result
        #expect(snapshots.count == 2)
        #expect(snapshots[0].createdAt != nil)
        #expect(snapshots[1].createdAt == nil)
        let bundle = CollectionDetailBundle(name: "x", snapshots: snapshots)
        #expect(bundle.sortedSnapshots.first?.name.contains("2026-09-06") == true)
        #expect(bundle.snapshotSummary == "2 snapshots · 19.3 GB")
    }

    @Test("Byte sizes")
    func bytes() {
        #expect(ByteSize.string(0) == "0 B")
        #expect(ByteSize.string(1536) == "1.5 KB")
        #expect(ByteSize.string(10_951_393_280) == "10.2 GB")
    }
}

@Suite("Detail client calls")
struct DetailClientTests {
    private func client(_ status: Int = 200, body: String) -> QdrantClient {
        QdrantClient(transport: MockHTTPTransport { _ in
            MockHTTPTransport.makeResponse(statusCode: status, data: Data(body.utf8))
        })
    }

    @Test("Snapshots and aliases come from the right paths, with the key")
    func paths() async throws {
        let seen = PathRecorder()
        let transport = MockHTTPTransport { request in
            seen.add(request.url?.path ?? "", key: request.value(forHTTPHeaderField: "api-key"))
            let body = request.url?.path.hasSuffix("/aliases") == true ? #"{"result":{"aliases":[{"alias_name":"live","collection_name":"a b"}]}}"# : #"{"result":[]}"#
            return MockHTTPTransport.makeResponse(statusCode: 200, data: Data(body.utf8))
        }
        let client = QdrantClient(apiKey: "k", transport: transport)
        let aliases = try await client.fetchAliases(collection: "a b")
        _ = try await client.fetchSnapshots(collection: "a b")
        #expect(aliases.first?.aliasName == "live")
        #expect(seen.paths == ["/collections/a%20b/aliases", "/collections/a%20b/snapshots"])
        #expect(seen.keys == ["k", "k"])
    }

    @Test("A 401 on a detail call is unauthorized, a 404 is not found")
    func errors() async {
        await #expect(throws: QdrantClientError.unauthorized) { try await client(401, body: "{}").fetchSnapshots(collection: "x") }
        await #expect(throws: QdrantClientError.notFound("x")) { try await client(404, body: "{}").fetchAliases(collection: "x") }
    }

    @Test("Copy JSON returns the pretty-printed result object")
    func prettyJSON() async throws {
        let text = try await client(body: #"{"result":{"status":"green","points_count":5},"status":"ok"}"#).fetchCollectionJSON(name: "x")
        #expect(text.contains("\"points_count\" : 5"))
        #expect(!text.contains("\"result\""))
    }
}

final class PathRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedPaths: [String] = []
    private var storedKeys: [String?] = []
    func add(_ path: String, key: String?) { lock.withLock { storedPaths.append(path); storedKeys.append(key) } }
    var paths: [String] { lock.withLock { storedPaths } }
    var keys: [String?] { lock.withLock { storedKeys } }
}
