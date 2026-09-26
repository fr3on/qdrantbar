import Foundation
import Testing
@testable import QdrantBarCore

@Suite("QdrantClient & Models Tests")
struct QdrantClientTests {
    private func loadFixtureData(name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? Bundle.module.url(forResource: name, withExtension: "json") else {
            fatalError("Could not locate fixture \(name).json in Bundle.module")
        }
        return try Data(contentsOf: url)
    }

    @Test("Test decoding single vector collection fixture")
    func testDecodeSingleVectorCollection() throws {
        let data = try loadFixtureData(name: "collection_detail_single_vector")
        let response = try JSONDecoder().decode(QdrantResponse<CollectionDetail>.self, from: data)

        #expect(response.status == "ok")
        #expect(response.result.status == .green)
        #expect(response.result.pointsCount == 15420)
        #expect(response.result.vectorsCount == 15420)
        #expect(response.result.segmentsCount == 4)

        if case let .single(params) = response.result.config?.params?.vectors {
            #expect(params.size == 1536)
            #expect(params.distance == .cosine)
        } else {
            Issue.record("Expected single vector configuration")
        }
    }

    @Test("Test decoding multi-vector collection fixture")
    func testDecodeMultiVectorCollection() throws {
        let data = try loadFixtureData(name: "collection_detail_multi_vectors")
        let response = try JSONDecoder().decode(QdrantResponse<CollectionDetail>.self, from: data)

        #expect(response.status == "ok")
        #expect(response.result.status == .yellow)
        #expect(response.result.pointsCount == 4100)
        #expect(response.result.vectorsCount == 8200)

        if case let .multiple(dict) = response.result.config?.params?.vectors {
            #expect(dict.count == 2)
            #expect(dict["text"]?.size == 768)
            #expect(dict["text"]?.distance == .cosine)
            #expect(dict["image"]?.size == 512)
            #expect(dict["image"]?.distance == .dot)
        } else {
            Issue.record("Expected multiple vector configuration")
        }
    }

    @Test("Test health check client request")
    func testCheckHealth() async throws {
        let data = try loadFixtureData(name: "healthz")
        let transport = MockHTTPTransport { request in
            #expect(request.url?.path == "/healthz")
            return MockHTTPTransport.makeResponse(statusCode: 200, data: data)
        }

        let client = QdrantClient(transport: transport)
        let health = try await client.checkHealth()
        #expect(health.isHealthy == true)
        #expect(health.version == "1.13.0")
    }

    @Test("Test version fetching client request")
    func testFetchVersion() async throws {
        let data = try loadFixtureData(name: "root_version")
        let transport = MockHTTPTransport { request in
            #expect(request.url?.path == "/")
            return MockHTTPTransport.makeResponse(statusCode: 200, data: data)
        }

        let client = QdrantClient(transport: transport)
        let version = try await client.fetchVersion()
        #expect(version.version == "1.13.0")
        #expect(version.title.contains("qdrant"))
    }

    @Test("Test collections list client request")
    func testFetchCollections() async throws {
        let data = try loadFixtureData(name: "collections")
        let transport = MockHTTPTransport { request in
            #expect(request.url?.path == "/collections")
            return MockHTTPTransport.makeResponse(statusCode: 200, data: data)
        }

        let client = QdrantClient(transport: transport)
        let collections = try await client.fetchCollections()
        #expect(collections.count == 2)
        #expect(collections.map(\.name) == ["articles", "products"])
    }

    @Test("Test API key header transmission")
    func testApiKeyHeader() async throws {
        let data = try loadFixtureData(name: "collections")
        let transport = MockHTTPTransport { request in
            #expect(request.value(forHTTPHeaderField: "api-key") == "secret-key-123")
            return MockHTTPTransport.makeResponse(statusCode: 200, data: data)
        }

        let client = QdrantClient(apiKey: "secret-key-123", transport: transport)
        _ = try await client.fetchCollections()
    }

    @Test("Test 401 Unauthorized handling")
    func testUnauthorizedError() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTPTransport.makeResponse(statusCode: 401, data: Data())
        }

        let client = QdrantClient(transport: transport)
        await #expect(throws: QdrantClientError.unauthorized) {
            _ = try await client.fetchCollections()
        }
    }
}

@Suite("Auth handling")
struct AuthTests {
    @Test("healthz can pass while collections are unauthorized")
    func healthOkButUnauthorized() async throws {
        let transport = MockHTTPTransport { request in
            let path = request.url?.path ?? ""
            if path == "/healthz" {
                return MockHTTPTransport.makeResponse(statusCode: 200, data: Data("healthz check passed".utf8))
            }
            return MockHTTPTransport.makeResponse(statusCode: 401, data: Data())
        }
        let client = QdrantClient(transport: transport)
        let health = try await client.checkHealth()
        #expect(health.isHealthy)
        await #expect(throws: QdrantClientError.unauthorized) { try await client.fetchCollections() }
        await #expect(throws: QdrantClientError.unauthorized) { try await client.fetchVersion() }
    }
}
