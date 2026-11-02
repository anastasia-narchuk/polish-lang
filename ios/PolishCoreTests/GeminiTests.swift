import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PolishCore

/// A generateContent reply whose first candidate holds `text`, with a thought part before it.
func geminiReply(_ text: String, finishReason: String = "STOP") -> MockTransport.Reply {
    let body: JSONValue = [
        "candidates": [[
            "content": ["role": "model", "parts": [["text": "thinking…", "thought": true], ["text": .string(text)]]],
            "finishReason": .string(finishReason),
        ]],
        "modelVersion": "gemini-3.5-flash",
    ]
    return MockTransport.Reply(status: 200, body: String(decoding: try! body.encoded(), as: UTF8.self))
}

func geminiConfig(model: String = GeminiClient.defaultModel) -> AIConfiguration {
    AIConfiguration(apiKey: "AQ.test", provider: .gemini, model: model, baseURL: GeminiClient.defaultBaseURL, refusalFallback: false)
}

final class GeminiTests: XCTestCase {
    func testRequestShape() throws {
        let image = AIImage(mediaType: "image/jpeg", data: Data([1, 2, 3]))
        let request = AIRequest(prompt: "Cześć", images: [image], maxTokens: 16_000, effort: .medium, schema: Schemas.translation)
        let urlRequest = try GeminiClient(transport: MockTransport([])).makeURLRequest(request, config: geminiConfig())

        XCTAssertEqual(urlRequest.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent")
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-goog-api-key"), "AQ.test")
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "x-api-key"))

        let body = try XCTUnwrap(JSONValue.decode(urlRequest.httpBody!))
        let parts = try XCTUnwrap(body["contents"]?.arrayValue?.first?["parts"]?.arrayValue)
        XCTAssertEqual(parts.count, 2, "the image goes before the text, as for Claude")
        XCTAssertEqual(parts[0]["inlineData"]?["mimeType"], "image/jpeg")
        XCTAssertEqual(parts[0]["inlineData"]?["data"], .string(Data([1, 2, 3]).base64EncodedString()))
        XCTAssertEqual(parts[1]["text"], "Cześć")
        let generation = try XCTUnwrap(body["generationConfig"])
        XCTAssertEqual(generation["maxOutputTokens"], 16_000)
        XCTAssertEqual(generation["responseMimeType"], "application/json")
        XCTAssertEqual(generation["responseJsonSchema"], Schemas.translation)
        XCTAssertEqual(generation["thinkingConfig"]?["thinkingLevel"], "medium")
    }

    func testPlainTextRequestHasNoSchemaAndOlderModelsNoThinkingLevel() throws {
        let request = AIRequest(prompt: "x", maxTokens: 100, effort: .low)
        let body = GeminiClient.body(for: request, model: "gemma-4-31b-it")
        XCTAssertNil(body["generationConfig"]?["responseMimeType"])
        XCTAssertNil(body["generationConfig"]?["thinkingConfig"])
        XCTAssertTrue(GeminiClient.supportsThinkingLevel("gemini-3.8-flash"))
        XCTAssertTrue(GeminiClient.supportsThinkingLevel("gemini-flash-latest"))
        XCTAssertFalse(GeminiClient.supportsThinkingLevel("gemini-2.5-flash"))
    }

    func testThoughtPartsAreSkipped() throws {
        let response = try GeminiClient.parseResponse(Data(geminiReply(#"{"a":1}"#).body.utf8))
        XCTAssertEqual(response.text, #"{"a":1}"#)
        XCTAssertEqual(response.model, "gemini-3.5-flash")
    }

    func testBlocksAndCutRepliesAreErrors() {
        let cases: [(String, AIError)] = [
            (geminiReply("{", finishReason: "MAX_TOKENS").body, .truncated),
            (geminiReply("", finishReason: "SAFETY").body, .refusal),
            (#"{"promptFeedback":{"blockReason":"PROHIBITED_CONTENT"}}"#, .refusal),
            (#"{"candidates":[]}"#, .refusal),
            ("not json", .invalidResponse),
        ]
        for (body, expected) in cases {
            XCTAssertThrowsError(try GeminiClient.parseResponse(Data(body.utf8)), body) {
                XCTAssertEqual($0 as? AIError, expected, body)
            }
        }
    }

    func testErrorMapping() async {
        let perMinute = #"{"error":{"code":429,"message":"You exceeded your current quota.","status":"RESOURCE_EXHAUSTED","details":[{"@type":"type.googleapis.com/google.rpc.QuotaFailure","violations":[{"quotaMetric":"generativelanguage.googleapis.com/generate_content_free_tier_requests","quotaId":"GenerateRequestsPerMinutePerProjectPerModel-FreeTier"}]},{"@type":"type.googleapis.com/google.rpc.RetryInfo","retryDelay":"40.2s"}]}}"#
        let perDay = #"{"error":{"code":429,"message":"You exceeded your current quota.","status":"RESOURCE_EXHAUSTED","details":[{"@type":"type.googleapis.com/google.rpc.QuotaFailure","violations":[{"quotaId":"GenerateRequestsPerDayPerProjectPerModel-FreeTier"}]}]}}"#
        let cases: [(Int, String, AIError)] = [
            // The reply of a key whose project has billing linked and no prepaid credit (seen 02.11).
            (402, #"{"error":{"code":402,"message":"Your prepayment credits are depleted. Please go to AI Studio at https://ai.studio/projects to manage your project and billing.","status":"RESOURCE_EXHAUSTED"}}"#, .paymentRequired),
            (429, perMinute, .rateLimited(retryAfter: 41)),
            (429, perDay, .dailyLimit),
            (400, #"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT","details":[{"reason":"API_KEY_INVALID"}]}}"#, .unauthorized),
            (400, #"{"error":{"code":400,"message":"User location is not supported for the API use.","status":"FAILED_PRECONDITION"}}"#, .forbidden("User location is not supported for the API use.")),
            (404, #"{"error":{"code":404,"message":"This model models/gemini-2.5-flash is no longer available to new users.","status":"NOT_FOUND"}}"#, .modelNotFound(GeminiClient.defaultModel)),
            (503, #"{"error":{"code":503,"message":"This model is currently experiencing high demand.","status":"UNAVAILABLE"}}"#, .overloaded),
        ]
        for (status, body, expected) in cases {
            let client = GeminiClient(transport: MockTransport([MockTransport.Reply(status: status, body: body)]))
            do {
                _ = try await client.send(AIRequest(prompt: "x", maxTokens: 10, effort: .low), config: geminiConfig())
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? AIError, expected, "HTTP \(status)")
            }
        }
    }

    func testOverloadedModelFallsBackOnceToTheLighterOne() async throws {
        let busy = MockTransport.Reply(status: 503, body: #"{"error":{"code":503,"message":"This model is currently experiencing high demand.","status":"UNAVAILABLE"}}"#)
        var config = geminiConfig()
        config.overloadFallbackModel = GeminiClient.fallbackModel
        let transport = MockTransport([busy, geminiReply("ok")])
        let response = try await GeminiClient(transport: transport).send(AIRequest(prompt: "x", maxTokens: 10, effort: .low), config: config)
        XCTAssertEqual(response.text, "ok")
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertTrue(transport.requests[1].url?.absoluteString.hasSuffix("models/gemini-3.5-flash-lite:generateContent") == true)

        let bothBusy = MockTransport([busy, busy, geminiReply("never")])
        do {
            _ = try await GeminiClient(transport: bothBusy).send(AIRequest(prompt: "x", maxTokens: 10, effort: .low), config: config)
            XCTFail("expected overloaded")
        } catch {
            XCTAssertEqual(error as? AIError, .overloaded)
            XCTAssertEqual(bothBusy.requests.count, 2, "one repeat, not a loop")
        }
    }

    func testCheckConnectionSpendsOneSmallRequest() async throws {
        let transport = MockTransport([geminiReply("ta", finishReason: "MAX_TOKENS")])
        try await GeminiClient(transport: transport).checkConnection(config: geminiConfig())
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.lastBody?["generationConfig"]?["maxOutputTokens"], 1_024)
    }

    @MainActor
    func testServiceUsesTheChosenProviderAndItsKey() async throws {
        let secrets = InMemorySecretStore()
        secrets.save("AQ.test", account: "gemini-api-key")
        let settings = AppSettings(defaults: UserDefaults(suiteName: "gemini-tests-\(UUID().uuidString)")!)
        let ai = AIService(settings: settings, secrets: secrets)
        XCTAssertFalse(ai.hasKey, "Claude is the default provider and has no key")
        settings.provider = .gemini
        XCTAssertTrue(ai.hasKey)

        let transport = MockTransport([geminiReply(#"{"ru":"врача (род. п.)","base":"lekarz","pos":"","form":"D. l.poj.","alternation":"","note":"","sentence_ru":""}"#)])
        ai.geminiClient = GeminiClient(transport: transport)
        let translation = try await ai.translate(selection: "lekarza", sentence: "Idę do lekarza.", title: "")
        XCTAssertEqual(translation.base, "lekarz")
        XCTAssertEqual(transport.requests.first?.url?.host, "generativelanguage.googleapis.com")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "x-goog-api-key"), "AQ.test")

        ai.deleteKey()
        XCTAssertFalse(ai.hasKey)
        XCTAssertNil(secrets.read("gemini-api-key"))
    }
}
