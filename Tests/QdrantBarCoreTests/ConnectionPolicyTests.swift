import Foundation
import Testing
@testable import QdrantBarCore

@Suite("Connection policy")
struct ConnectionPolicyTests {
    @Test("Only remote plain http needs an opt-in")
    func requiresOptIn() {
        // Loopback, https and non-http never do.
        for url in ["http://localhost:6333", "http://127.0.0.1:6333", "http://127.5.5.5", "http://[::1]:6333", "http://qdrant.localhost:6333",
                    "https://15.188.111.114:6333", "https://cloud.qdrant.io"] {
            #expect(!ConnectionPolicy.requiresInsecureOptIn(url), "\(url)")
        }
        // Public IPs, LAN addresses, hostnames and look-alikes do.
        for url in ["http://15.188.111.114:6333", "http://192.168.1.10:6333", "http://10.0.0.5", "http://qdrant.internal:6333",
                    "http://localhost.evil.com:6333", "HTTP://EXAMPLE.COM"] {
            #expect(ConnectionPolicy.requiresInsecureOptIn(url), "\(url)")
        }
    }

    @Test("Garbage input is not an opt-in case")
    func garbage() {
        #expect(!ConnectionPolicy.requiresInsecureOptIn(""))
        #expect(!ConnectionPolicy.requiresInsecureOptIn("not a url"))
        #expect(!ConnectionPolicy.requiresInsecureOptIn("ftp://example.com"))
    }

    @Test("Profiles saved before the option existed load as not allowed")
    func oldProfile() throws {
        let json = #"{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","name":"Old","urlString":"http://10.0.0.5:6333","environmentTag":"Production"}"#
        let profile = try JSONDecoder().decode(ServerProfile.self, from: Data(json.utf8))
        #expect(profile.allowInsecureHTTP == false)
        #expect(!profile.isInsecureRemote)
    }

    @Test("A profile round-trips, and the flag only counts for remote http")
    func roundTrip() throws {
        let remote = ServerProfile(name: "r", urlString: "http://10.0.0.5:6333", allowInsecureHTTP: true)
        let decoded = try JSONDecoder().decode(ServerProfile.self, from: JSONEncoder().encode(remote))
        #expect(decoded == remote)
        #expect(decoded.isInsecureRemote)
        #expect(!ServerProfile(name: "l", urlString: "http://localhost:6333", allowInsecureHTTP: true).isInsecureRemote)
        #expect(!ServerProfile(name: "s", urlString: "https://example.com", allowInsecureHTTP: true).isInsecureRemote)
    }
}

@Suite("Client enforces the policy")
struct ClientPolicyTests {
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func bump() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }

    private func transport(counting counter: Counter) -> MockHTTPTransport {
        MockHTTPTransport { _ in
            counter.bump()
            return MockHTTPTransport.makeResponse(statusCode: 200, data: Data(#"{"status":"ok","result":{"collections":[]}}"#.utf8))
        }
    }

    @Test("Remote http is refused before any request or API key leaves the app")
    func refused() async {
        let counter = Counter()
        let client = QdrantClient(baseURL: URL(string: "http://15.188.111.114:6333")!, apiKey: "secret", transport: transport(counting: counter))
        await #expect(throws: QdrantClientError.insecureConnection(host: "15.188.111.114")) { try await client.checkHealth() }
        await #expect(throws: QdrantClientError.insecureConnection(host: "15.188.111.114")) { try await client.fetchCollections() }
        await #expect(throws: QdrantClientError.insecureConnection(host: "15.188.111.114")) { try await client.fetchSnapshots(collection: "x") }
        #expect(counter.count == 0)
    }

    @Test("The opt-in lets the same server through")
    func allowed() async throws {
        let counter = Counter()
        let client = QdrantClient(baseURL: URL(string: "http://15.188.111.114:6333")!, allowInsecureHTTP: true, transport: transport(counting: counter))
        _ = try await client.fetchCollections()
        #expect(counter.count == 1)
    }

    @Test("The opt-in can be granted later, on a live client")
    func grantedLater() async throws {
        let counter = Counter()
        let client = QdrantClient(baseURL: URL(string: "http://10.0.0.5:6333")!, transport: transport(counting: counter))
        await #expect(throws: QdrantClientError.insecureConnection(host: "10.0.0.5")) { try await client.fetchCollections() }
        await client.updateAllowInsecureHTTP(true)
        _ = try await client.fetchCollections()
        #expect(counter.count == 1)
    }

    @Test("Loopback and https never need the opt-in")
    func neverNeeded() async throws {
        for base in ["http://localhost:6333", "http://127.0.0.1:6333", "https://15.188.111.114:6333"] {
            let counter = Counter()
            let client = QdrantClient(baseURL: URL(string: base)!, transport: transport(counting: counter))
            _ = try await client.fetchCollections()
            #expect(counter.count == 1, "\(base)")
        }
    }

    @Test("A system ATS block becomes the friendly error, not a raw network error")
    func atsMapped() async {
        let url = URL(string: "http://example.com:6333")!
        let transport = MockHTTPTransport { _ in
            throw URLError(.appTransportSecurityRequiresSecureConnection, userInfo: [NSURLErrorFailingURLErrorKey: url])
        }
        let client = QdrantClient(baseURL: URL(string: "https://example.com:6333")!, transport: transport)
        await #expect(throws: QdrantClientError.insecureConnection(host: "example.com")) { try await client.fetchCollections() }
    }

    @Test("The friendly message names the host and the ways out")
    func message() {
        let text = QdrantClientError.insecureConnection(host: "15.188.111.114").errorDescription ?? ""
        #expect(text.contains("15.188.111.114"))
        #expect(text.contains("https"))
        #expect(text.contains("SSH tunnel"))
        #expect(text.contains("allow insecure HTTP"))
    }
}
