import Foundation
import QdrantBarCore

public final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    public typealias Handler = @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)
    private var handler: Handler?

    public init(handler: Handler? = nil) {
        self.handler = handler
    }

    public func setHandler(_ handler: @escaping Handler) {
        self.handler = handler
    }

    public func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let handler else {
            fatalError("MockHTTPTransport handler not set")
        }
        return try handler(request)
    }

    public static func makeResponse(
        statusCode: Int,
        data: Data,
        url: URL = URL(string: "http://localhost:6333")!
    ) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}
