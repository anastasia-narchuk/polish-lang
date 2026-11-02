import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Gemini API (`generateContent`) over plain HTTP. The same prompts and JSON schemas as for Claude:
/// structured output goes to `responseJsonSchema`, images become inline parts before the text.
struct GeminiClient: AIBackend {
    static let defaultModel = "gemini-3.5-flash"
    /// Answers when the chosen model is overloaded: the free tier often is (seen 02.11).
    static let fallbackModel = "gemini-3.5-flash-lite"
    static let defaultBaseURL = URL(string: "https://generativelanguage.googleapis.com")!

    var transport: HTTPTransport = URLSessionTransport()
    var timeout: TimeInterval = 180

    func send(_ request: AIRequest, config: AIConfiguration) async throws -> AIResponse {
        guard !config.apiKey.trimmed.isEmpty else { throw AIError.notConfigured }
        do {
            return try await perform(request, config: config)
        } catch AIError.overloaded {
            // One repeat with the lighter model, not a loop.
            guard let fallback = config.overloadFallbackModel, fallback != config.model else { throw AIError.overloaded }
            var lighter = config
            lighter.model = fallback
            return try await perform(request, config: lighter)
        }
    }

    private func perform(_ request: AIRequest, config: AIConfiguration) async throws -> AIResponse {
        let urlRequest = try makeURLRequest(request, config: config)
        let (data, http) = try await sendMapped(urlRequest)
        guard (200..<300).contains(http.statusCode) else { throw Self.error(for: http, data: data, model: config.model) }
        return try Self.parseResponse(data)
    }

    /// A key whose project has billing linked but no prepaid credit still lists models and only
    /// fails on generation (402), so the check makes one tiny request: one request of the daily quota.
    func checkConnection(config: AIConfiguration) async throws {
        do {
            _ = try await send(AIRequest(prompt: "Odpowiedz jednym słowem: tak", maxTokens: 1_024, effort: .low), config: config)
        } catch AIError.truncated {
            // The model answered; the answer just did not fit. The key and the model work.
        }
    }

    func makeURLRequest(_ request: AIRequest, config: AIConfiguration) throws -> URLRequest {
        let url = config.baseURL
            .appendingPathComponent("v1beta")
            .appendingPathComponent("models")
            .appendingPathComponent(config.model + ":generateContent")
        var urlRequest = URLRequest(url: url, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(config.apiKey.trimmed, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.httpBody = try Self.body(for: request, model: config.model).encoded()
        return urlRequest
    }

    static func body(for request: AIRequest, model: String) -> JSONValue {
        var parts: [JSONValue] = request.images.map { image in
            ["inlineData": ["mimeType": .string(image.mediaType), "data": .string(image.data.base64EncodedString())]]
        }
        parts.append(["text": .string(request.prompt)])

        var generation: [String: JSONValue] = ["maxOutputTokens": .int(request.maxTokens)]
        if let schema = request.schema {
            generation["responseMimeType"] = "application/json"
            generation["responseJsonSchema"] = schema
        }
        if supportsThinkingLevel(model) {
            generation["thinkingConfig"] = ["thinkingLevel": .string(request.effort.rawValue)]
        }
        return [
            "contents": [["role": "user", "parts": .array(parts)]],
            "generationConfig": .object(generation),
        ]
    }

    /// Gemini 3 and later take `thinkingLevel`; older models and Gemma reject it.
    static func supportsThinkingLevel(_ model: String) -> Bool {
        let name = model.lowercased()
        return name.hasPrefix("gemini") && !name.hasPrefix("gemini-1") && !name.hasPrefix("gemini-2")
    }

    /// Text of the first candidate without thought parts. A blocked prompt or a safety stop is a
    /// refusal, a reply cut at the token limit is `truncated`.
    static func parseResponse(_ data: Data) throws -> AIResponse {
        guard let json = JSONValue.decode(data), json.objectValue != nil else { throw AIError.invalidResponse }
        if let reason = json["promptFeedback"]?["blockReason"]?.stringValue, !reason.isEmpty {
            throw AIError.refusal
        }
        guard let candidate = json["candidates"]?.arrayValue?.first else { throw AIError.refusal }
        let finish = candidate["finishReason"]?.stringValue
        switch finish {
        case "MAX_TOKENS":
            throw AIError.truncated
        case "SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII", "RECITATION", "IMAGE_SAFETY":
            throw AIError.refusal
        default:
            break
        }
        let text = (candidate["content"]?["parts"]?.arrayValue ?? [])
            .filter { $0["thought"]?.boolValue != true }
            .compactMap { $0["text"]?.stringValue }
            .joined()
        return AIResponse(text: text, stopReason: finish, model: json["modelVersion"]?.stringValue)
    }

    static func error(for response: HTTPURLResponse, data: Data, model: String) -> AIError {
        let error = JSONValue.decode(data)?["error"]
        let message = error?["message"]?.stringValue ?? "HTTP \(response.statusCode)"
        let status = error?["status"]?.stringValue ?? ""
        let details = error?["details"]?.arrayValue ?? []
        let keyProblem = message.localizedCaseInsensitiveContains("API key")
            || details.contains { ($0["reason"]?.stringValue ?? "").hasPrefix("API_KEY") }
        switch response.statusCode {
        case 400:
            if keyProblem { return .unauthorized }
            if status == "FAILED_PRECONDITION" { return .forbidden(message) }
            return .badRequest(message)
        case 401:
            return .unauthorized
        case 402:
            return .paymentRequired
        case 403:
            return keyProblem ? .unauthorized : .forbidden(message)
        case 404:
            return .modelNotFound(model)
        case 408, 504:
            return .timeout
        case 413:
            return .badRequest("запрос слишком большой, уменьши число или размер фото")
        case 429:
            if isDailyQuota(details) { return .dailyLimit }
            return .rateLimited(retryAfter: retryDelay(details) ?? response.value(forHTTPHeaderField: "retry-after").flatMap { TimeInterval($0.trimmed) })
        case 503:
            return .overloaded
        case 500...599:
            return .server(response.statusCode)
        default:
            return .badRequest(message)
        }
    }

    /// `QuotaFailure` names the exhausted quota, e.g. "GenerateRequestsPerDayPerProjectPerModel-FreeTier".
    static func isDailyQuota(_ details: [JSONValue]) -> Bool {
        details.contains { detail in
            (detail["violations"]?.arrayValue ?? []).contains { violation in
                let id = (violation["quotaId"]?.stringValue ?? "") + (violation["quotaMetric"]?.stringValue ?? "")
                return id.localizedCaseInsensitiveContains("PerDay")
            }
        }
    }

    /// `RetryInfo.retryDelay` such as "41s" or "2.5s".
    static func retryDelay(_ details: [JSONValue]) -> TimeInterval? {
        for detail in details {
            guard let delay = detail["retryDelay"]?.stringValue, delay.hasSuffix("s") else { continue }
            if let seconds = TimeInterval(delay.dropLast()) { return seconds.rounded(.up) }
        }
        return nil
    }

    private func sendMapped(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch let error as AIError {
            throw error
        } catch is CancellationError {
            throw AIError.cancelled
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw AIError.cancelled
            case .timedOut: throw AIError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                throw AIError.offline
            default: throw AIError.network(error.localizedDescription)
            }
        } catch {
            throw AIError.network(error.localizedDescription)
        }
    }
}
