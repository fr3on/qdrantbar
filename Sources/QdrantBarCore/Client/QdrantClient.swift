import Foundation

public protocol HTTPTransport: Sendable {
    func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QdrantClientError.invalidResponse
        }
        return (data, httpResponse)
    }
}

public enum QdrantClientError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound(String)
    case serverError(Int, String)
    case decodingError(String)
    case networkError(String)
    /// A remote `http://` server that has not been allowed.
    case insecureConnection(host: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Qdrant URL"
        case .invalidResponse:
            return "Received an invalid HTTP response from Qdrant"
        case .unauthorized:
            return "Unauthorized: Invalid or missing API key"
        case let .notFound(resource):
            return "Resource not found: \(resource)"
        case let .serverError(code, message):
            return "Qdrant server error (\(code)): \(message)"
        case let .decodingError(details):
            return "Failed to decode Qdrant response: \(details)"
        case let .networkError(message):
            return "Network error: \(message)"
        case let .insecureConnection(host):
            return "\(host) uses plain http://, and macOS blocks unencrypted connections to remote hosts. Use https or an SSH tunnel, or allow insecure HTTP for this server."
        }
    }
}

public actor QdrantClient {
    public var baseURL: URL
    public var apiKey: String?
    public var allowInsecureHTTP: Bool
    private let transport: HTTPTransport

    public init(
        baseURL: URL = URL(string: "http://localhost:6333")!,
        apiKey: String? = nil,
        allowInsecureHTTP: Bool = false,
        transport: HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.allowInsecureHTTP = allowInsecureHTTP
        self.transport = transport
    }

    public func updateAllowInsecureHTTP(_ allowed: Bool) {
        self.allowInsecureHTTP = allowed
    }

    /// The single place where transport failures become friendly errors.
    private static func map(_ error: Error) -> QdrantClientError {
        if let clientError = error as? QdrantClientError { return clientError }
        if let urlError = error as? URLError, urlError.code == .appTransportSecurityRequiresSecureConnection {
            return .insecureConnection(host: urlError.failingURL?.host ?? "This server")
        }
        return .networkError(error.localizedDescription)
    }

    public func updateBaseURL(_ url: URL) {
        self.baseURL = url
    }

    public func updateApiKey(_ key: String?) {
        self.apiKey = key
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem]? = nil, timeout: TimeInterval = 10.0) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw QdrantClientError.invalidURL
        }
        // Refuse before anything (least of all the API key) is sent over an unallowed plain-HTTP connection.
        if ConnectionPolicy.requiresInsecureOptIn(baseURL) && !allowInsecureHTTP {
            throw QdrantClientError.insecureConnection(host: baseURL.host ?? "This server")
        }

        let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let newPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + (existingPath.isEmpty ? newPath : "\(existingPath)/\(newPath)")
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let requestURL = components.url else {
            throw QdrantClientError.invalidURL
        }

        var request = URLRequest(url: requestURL, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
        }

        return request
    }

    public func checkHealth() async throws -> HealthResponse {
        var request = try makeRequest(path: "healthz", timeout: 2.0)
        request.timeoutInterval = 2.0

        do {
            let (data, response) = try await transport.execute(request: request)
            guard (200...299).contains(response.statusCode) else {
                throw QdrantClientError.serverError(response.statusCode, "Health check returned status \(response.statusCode)")
            }

            if let health = try? JSONDecoder().decode(HealthResponse.self, from: data) {
                return health
            }
            return HealthResponse(status: "ok")
        } catch {
            throw Self.map(error)
        }
    }

    public func fetchVersion() async throws -> QdrantVersion {
        let request = try makeRequest(path: "")
        let (data, response) = try await send(request: request)

        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw QdrantClientError.unauthorized
            }
            throw QdrantClientError.serverError(response.statusCode, "Failed to fetch version")
        }

        do {
            return try JSONDecoder().decode(QdrantVersion.self, from: data)
        } catch {
            throw QdrantClientError.decodingError(error.localizedDescription)
        }
    }

    public func fetchCollections() async throws -> [CollectionSummary] {
        let request = try makeRequest(path: "collections")
        let (data, response) = try await send(request: request)

        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw QdrantClientError.unauthorized
            }
            throw QdrantClientError.serverError(response.statusCode, "Failed to fetch collections")
        }

        do {
            let decoded = try JSONDecoder().decode(QdrantResponse<CollectionsListResult>.self, from: data)
            return decoded.result.collections
        } catch {
            throw QdrantClientError.decodingError(error.localizedDescription)
        }
    }

    public func fetchCollectionDetails(name: String) async throws -> CollectionDetail {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let request = try makeRequest(path: "collections/\(encodedName)")
        let (data, response) = try await send(request: request)

        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 404 {
                throw QdrantClientError.notFound(name)
            }
            if response.statusCode == 401 || response.statusCode == 403 {
                throw QdrantClientError.unauthorized
            }
            throw QdrantClientError.serverError(response.statusCode, "Failed to fetch collection details for \(name)")
        }

        do {
            let decoded = try JSONDecoder().decode(QdrantResponse<CollectionDetail>.self, from: data)
            return decoded.result
        } catch {
            throw QdrantClientError.decodingError(error.localizedDescription)
        }
    }

    public func fetchTelemetry() async throws -> TelemetryInfo {
        let query = [URLQueryItem(name: "detail_level", value: "0")]
        let request = try makeRequest(path: "telemetry", queryItems: query)
        let (data, response) = try await send(request: request)

        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw QdrantClientError.unauthorized
            }
            throw QdrantClientError.serverError(response.statusCode, "Failed to fetch telemetry")
        }

        do {
            let decoded = try JSONDecoder().decode(QdrantResponse<TelemetryInfo>.self, from: data)
            return decoded.result
        } catch {
            throw QdrantClientError.decodingError(error.localizedDescription)
        }
    }

    // MARK: Collection detail (read-only)

    public func fetchAliases(collection name: String) async throws -> [AliasDescription] {
        try await getResult("collections/\(Self.encode(name))/aliases", as: AliasesResult.self, resource: name).aliases
    }

    public func fetchSnapshots(collection name: String) async throws -> [SnapshotDescription] {
        try await getResult("collections/\(Self.encode(name))/snapshots", as: [SnapshotDescription].self, resource: name)
    }

    public func fetchOptimizations(collection name: String) async throws -> OptimizationsInfo {
        try await getResult("collections/\(Self.encode(name))/optimizations", as: OptimizationsInfo.self, resource: name)
    }

    /// The collection's `result` object as pretty-printed JSON, for the "Copy JSON" action.
    public func fetchCollectionJSON(name: String) async throws -> String {
        let data = try await getData("collections/\(Self.encode(name))", resource: name)
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let result = object["result"],
              let pretty = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: pretty, encoding: .utf8)
        else {
            throw QdrantClientError.decodingError("Unexpected collection response")
        }
        return text
    }

    private static func encode(_ name: String) -> String {
        name.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? name
    }

    private func getData(_ path: String, resource: String) async throws -> Data {
        let request = try makeRequest(path: path)
        let (data, response) = try await send(request: request)
        guard (200...299).contains(response.statusCode) else {
            switch response.statusCode {
            case 401, 403: throw QdrantClientError.unauthorized
            case 404: throw QdrantClientError.notFound(resource)
            default: throw QdrantClientError.serverError(response.statusCode, "Request failed for \(resource)")
            }
        }
        return data
    }

    private func getResult<T: Decodable & Sendable>(_ path: String, as type: T.Type, resource: String) async throws -> T {
        let data = try await getData(path, resource: resource)
        do {
            return try JSONDecoder().decode(QdrantEnvelope<T>.self, from: data).result
        } catch {
            throw QdrantClientError.decodingError(error.localizedDescription)
        }
    }

    private func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.execute(request: request)
        } catch {
            throw Self.map(error)
        }
    }
}

/// Decode-only twin of `QdrantResponse` for result types that are not `Encodable`.
private struct QdrantEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let result: T
}
