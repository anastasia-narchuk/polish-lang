import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PolishCore

/// Replays canned HTTP responses and records the requests it received.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    struct Reply {
        var status: Int
        var body: String
        var headers: [String: String] = [:]
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) {
        self.replies = replies
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let reply: Reply = lock.withLock {
            requests.append(request)
            return replies.isEmpty ? Reply(status: 500, body: "{}") : replies.removeFirst()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        return (Data(reply.body.utf8), response)
    }

    var lastBody: JSONValue? {
        lock.withLock { requests.last?.httpBody.flatMap(JSONValue.decode) }
    }
}

/// A Messages API reply whose text block holds `text` (with a thinking block before it, as on current models).
func messageReply(_ text: String, stopReason: String = "end_turn") -> MockTransport.Reply {
    let body: JSONValue = [
        "id": "msg_test",
        "type": "message",
        "role": "assistant",
        "model": "claude-sonnet-5-5",
        "content": [
            ["type": "thinking", "thinking": "", "signature": "sig"],
            ["type": "text", "text": .string(text)],
        ],
        "stop_reason": .string(stopReason),
    ]
    return MockTransport.Reply(status: 200, body: String(decoding: try! body.encoded(), as: UTF8.self))
}

func testConfig() -> AIConfiguration {
    AIConfiguration(apiKey: "sk-ant-test")
}

/// Deterministic generator for shuffles in tests.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
