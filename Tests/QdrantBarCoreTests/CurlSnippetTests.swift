import Foundation
import Testing
@testable import QdrantBarCore

@Suite("CurlSnippet & ShellQuote")
struct CurlSnippetTests {
    @Test("Plain name produces a quoted URL")
    func plainName() {
        let cmd = CurlSnippet.collection(baseURL: "http://localhost:6333/", name: "docs_embeddings", apiKey: nil)
        #expect(cmd == "curl -X GET 'http://localhost:6333/collections/docs_embeddings'")
    }

    @Test("API key is sent as a quoted header")
    func apiKey() {
        let cmd = CurlSnippet.collection(baseURL: "http://localhost:6333", name: "a", apiKey: "k3y")
        #expect(cmd == "curl -X GET 'http://localhost:6333/collections/a' -H 'api-key: k3y'")
    }

    @Test("Hostile collection names cannot break out of the command")
    func hostileNames() {
        for name in ["x\"; rm -rf ~; \"", "$(touch /tmp/pwned)", "`id`", "a'b", "x; echo hi", "a b\nc", "../../etc/passwd"] {
            let cmd = CurlSnippet.collection(baseURL: "http://localhost:6333", name: name, apiKey: nil)
            let url = String(cmd.dropFirst("curl -X GET ".count))
            #expect(url.hasPrefix("'http://localhost:6333/collections/") && url.hasSuffix("'"))
            let inner = url.dropFirst().dropLast()
            #expect(!inner.contains { "\"$`;'\\ \n(".contains($0) })
            #expect(!inner.contains("/../"))
        }
    }

    @Test("A key containing a quote is escaped")
    func quotedKey() {
        #expect(ShellQuote.single("it's") == "'it'\\''s'")
        let cmd = CurlSnippet.collection(baseURL: "http://h", name: "a", apiKey: "k'; id; '")
        #expect(cmd.hasSuffix("-H 'api-key: k'\\''; id; '\\'''"))
    }
}
