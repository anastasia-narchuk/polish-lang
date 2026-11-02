import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PolishCore

final class ClientTests: XCTestCase {
    func testRequestShape() throws {
        let client = AnthropicClient(transport: MockTransport([]))
        let request = AIRequest(prompt: "Cześć", maxTokens: 4_000, effort: .low, schema: Schemas.translation)
        let urlRequest = try client.makeURLRequest(request, config: testConfig(), fallback: true)

        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "anthropic-version"), "2026-10-21")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "anthropic-beta"), "server-side-fallback-2026-07-01")

        let body = try XCTUnwrap(JSONValue.decode(urlRequest.httpBody!))
        XCTAssertEqual(body["model"], "claude-sonnet-5-5")
        XCTAssertEqual(body["max_tokens"], 4_000)
        XCTAssertEqual(body["fallbacks"], "default")
        XCTAssertEqual(body["output_config"]?["effort"], "low")
        XCTAssertEqual(body["output_config"]?["format"]?["type"], "json_schema")
        XCTAssertEqual(body["output_config"]?["format"]?["schema"]?["additionalProperties"], false)
        XCTAssertNil(body["temperature"], "sampling parameters are rejected on API version 2026-10-21")
        XCTAssertNil(body["thinking"])
        XCTAssertEqual(body["messages"]?.arrayValue?.first?["role"], "user")
    }

    func testFallbackOnlyForModelsThatSupportIt() async throws {
        let transport = MockTransport([messageReply("ok")])
        var config = testConfig()
        config.model = "claude-haiku-5-5"
        _ = try await AnthropicClient(transport: transport).send(AIRequest(prompt: "x", maxTokens: 10, effort: .low), config: config)
        XCTAssertNil(transport.requests[0].value(forHTTPHeaderField: "anthropic-beta"))
        XCTAssertNil(transport.lastBody?["fallbacks"])
    }

    func testRetriesWithoutFallbackWhenBetaIsRejected() async throws {
        let rejection = MockTransport.Reply(
            status: 400,
            body: #"{"type":"error","error":{"type":"invalid_request_error","message":"Unexpected value(s) `server-side-fallback-2026-07-01` for the `anthropic-beta` header."}}"#
        )
        let transport = MockTransport([rejection, messageReply("ok")])
        let response = try await AnthropicClient(transport: transport).send(AIRequest(prompt: "x", maxTokens: 10, effort: .low), config: testConfig())
        XCTAssertEqual(response.text, "ok")
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertNil(transport.requests[1].value(forHTTPHeaderField: "anthropic-beta"))
    }

    func testTextBlocksAreJoinedAndThinkingSkipped() throws {
        let data = Data(#"{"content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"a\":"},{"type":"text","text":"1}"}],"stop_reason":"end_turn","model":"claude-sonnet-5-5"}"#.utf8)
        let response = try AnthropicClient.parseResponse(data)
        XCTAssertEqual(response.text, #"{"a":1}"#)
    }

    func testRefusalAndTruncation() {
        XCTAssertThrowsError(try AnthropicClient.parseResponse(Data(#"{"content":[],"stop_reason":"refusal","stop_details":{"type":"refusal","category":"general_harms"}}"#.utf8))) {
            XCTAssertEqual($0 as? AIError, .refusal)
        }
        XCTAssertThrowsError(try AnthropicClient.parseResponse(Data(#"{"content":[{"type":"text","text":"{\"title\":"}],"stop_reason":"max_tokens"}"#.utf8))) {
            XCTAssertEqual($0 as? AIError, .truncated)
        }
    }

    func testHTTPErrors() async {
        let cases: [(MockTransport.Reply, AIError)] = [
            (.init(status: 401, body: "{}"), .unauthorized),
            (.init(status: 404, body: "{}"), .modelNotFound("claude-sonnet-5-5")),
            (.init(status: 429, body: "{}", headers: ["retry-after": "17"]), .rateLimited(retryAfter: 17)),
            (.init(status: 529, body: "{}"), .overloaded),
            (.init(status: 500, body: "{}"), .server(500)),
        ]
        for (reply, expected) in cases {
            do {
                var config = testConfig()
                config.refusalFallback = false
                _ = try await AnthropicClient(transport: MockTransport([reply])).send(AIRequest(prompt: "x", maxTokens: 10, effort: .low), config: config)
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? AIError, expected)
            }
        }
    }

    func testMissingKeyIsNotConfigured() async {
        do {
            _ = try await AnthropicClient(transport: MockTransport([])).send(AIRequest(prompt: "x", maxTokens: 10, effort: .low), config: AIConfiguration(apiKey: " "))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? AIError, .notConfigured)
            XCTAssertTrue((error as? AIError)?.meansUnavailable == true)
        }
    }

    func testConnectionCheckUsesModelsEndpoint() async throws {
        let transport = MockTransport([MockTransport.Reply(status: 200, body: #"{"id":"claude-sonnet-5-5"}"#)])
        try await AnthropicClient(transport: transport).checkConnection(config: testConfig())
        XCTAssertEqual(transport.requests[0].url?.absoluteString, "https://api.anthropic.com/v1/models/claude-sonnet-5-5")
        XCTAssertEqual(transport.requests[0].httpMethod, "GET")
    }

    func testTolerantJSON() {
        XCTAssertEqual(TolerantJSON.parse(#"[{"a":1}]"#), [["a": 1]])
        XCTAssertEqual(TolerantJSON.parse("Вот ответ:\n```json\n{\"a\": 1}\n```\nГотово."), ["a": 1])
        XCTAssertEqual(TolerantJSON.parse("Ответ: [{\"a\": 1}] — всё."), [["a": 1]])
        XCTAssertNil(TolerantJSON.parse("Не могу помочь."))
        XCTAssertEqual(ResponseParser.items(in: [["a": 1]])?.count, 1)
        XCTAssertEqual(ResponseParser.items(in: ["items": [["a": 1], ["a": 2]]])?.count, 2)
        XCTAssertEqual(ResponseParser.items(in: ["words": [["a": 1]]])?.count, 1)
    }

    func testLenientFields() throws {
        let results = try ResponseParser.enrichResults(from: #"[{"ru":" реке ","isPolish":"false"}]"#, count: 1)
        XCTAssertEqual(results[0]?.ru, "реке")
        XCTAssertEqual(results[0]?.isPolish, false)
        XCTAssertEqual(results[0]?.base, "")
    }
}
