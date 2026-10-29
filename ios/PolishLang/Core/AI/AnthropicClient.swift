import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AIConfiguration: Equatable, Sendable {
    static let defaultModel = "claude-sonnet-5-5"
    static let defaultBaseURL = URL(string: "https://api.anthropic.com")!
    /// Models that accept the server-side refusal fallback (`fallbacks: "default"`).
    static let fallbackModels: Set<String> = ["claude-sonnet-5-5", "claude-opus-5-5", "claude-opus-5", "claude-fable-5-1"]

    var apiKey: String
    var model: String = AIConfiguration.defaultModel
    var baseURL: URL = AIConfiguration.defaultBaseURL
    var refusalFallback: Bool = true
}

enum AIEffort: String, Sendable {
    case low, medium, high
}

struct AIImage: Equatable, Sendable {
    var mediaType: String
    var data: Data
}

struct AIRequest: Sendable {
    var prompt: String
    var images: [AIImage] = []
    var maxTokens: Int
    var effort: AIEffort
    /// JSON schema for structured output (`output_config.format`).
    var schema: JSONValue?
}

struct AIResponse: Equatable, Sendable {
    var text: String
    var stopReason: String?
    var model: String?
}

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.network("сервер не ответил") }
        return (data, http)
    }
}

/// Claude Messages API over plain HTTP (there is no official Swift SDK).
struct AnthropicClient: Sendable {
    static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"

    var transport: HTTPTransport = URLSessionTransport()
    var timeout: TimeInterval = 180

    func send(_ request: AIRequest, config: AIConfiguration) async throws -> AIResponse {
        guard !config.apiKey.trimmed.isEmpty else { throw AIError.notConfigured }
        let fallback = config.refusalFallback && AIConfiguration.fallbackModels.contains(config.model)
        do {
            return try await perform(request, config: config, fallback: fallback)
        } catch AIError.badRequest(let message) where fallback && Self.rejectsFallback(message) {
            // The organization may not have the fallback beta: repeat once without it.
            return try await perform(request, config: config, fallback: false)
        }
    }

    /// Checks the key and the model without spending tokens: GET /v1/models/{model}.
    func checkConnection(config: AIConfiguration) async throws {
        guard !config.apiKey.trimmed.isEmpty else { throw AIError.notConfigured }
        let url = config.baseURL.appendingPathComponent("v1").appendingPathComponent("models").appendingPathComponent(config.model)
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        addHeaders(to: &request, config: config, fallback: false)
        let (data, http) = try await sendMapped(request)
        guard (200..<300).contains(http.statusCode) else { throw Self.error(for: http, data: data, model: config.model) }
    }

    func makeURLRequest(_ request: AIRequest, config: AIConfiguration, fallback: Bool) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent("v1").appendingPathComponent("messages")
        var urlRequest = URLRequest(url: url, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        addHeaders(to: &urlRequest, config: config, fallback: fallback)
        urlRequest.httpBody = try Self.body(for: request, model: config.model, fallback: fallback).encoded()
        return urlRequest
    }

    static func body(for request: AIRequest, model: String, fallback: Bool) -> JSONValue {
        var content: [JSONValue] = request.images.map { image in
            [
                "type": "image",
                "source": ["type": "base64", "media_type": .string(image.mediaType), "data": .string(image.data.base64EncodedString())],
            ]
        }
        content.append(["type": "text", "text": .string(request.prompt)])

        var outputConfig: [String: JSONValue] = ["effort": .string(request.effort.rawValue)]
        if let schema = request.schema {
            outputConfig["format"] = ["type": "json_schema", "schema": schema]
        }
        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .int(request.maxTokens),
            "messages": [["role": "user", "content": .array(content)]],
            "output_config": .object(outputConfig),
        ]
        if fallback { body["fallbacks"] = "default" }
        return .object(body)
    }

    /// Text of the reply. Thinking and other blocks are skipped; a refusal or a cut-off reply is an error.
    static func parseResponse(_ data: Data) throws -> AIResponse {
        guard let json = JSONValue.decode(data), json.objectValue != nil else { throw AIError.invalidResponse }
        let stopReason = json["stop_reason"]?.stringValue
        if stopReason == "refusal" { throw AIError.refusal }
        if stopReason == "max_tokens" { throw AIError.truncated }
        let text = (json["content"]?.arrayValue ?? [])
            .filter { $0["type"]?.stringValue == "text" }
            .compactMap { $0["text"]?.stringValue }
            .joined()
        return AIResponse(text: text, stopReason: stopReason, model: json["model"]?.stringValue)
    }

    static func error(for response: HTTPURLResponse, data: Data, model: String) -> AIError {
        let message = JSONValue.decode(data)?["error"]?["message"]?.stringValue ?? "HTTP \(response.statusCode)"
        switch response.statusCode {
        case 401: return .unauthorized
        case 402: return .billing
        case 403: return .forbidden(message)
        case 404: return .modelNotFound(model)
        case 408: return .timeout
        case 413: return .badRequest("запрос слишком большой, уменьши число или размер фото")
        case 429: return .rateLimited(retryAfter: response.value(forHTTPHeaderField: "retry-after").flatMap { TimeInterval($0.trimmed) })
        case 503, 529: return .overloaded
        case 500...599: return .server(response.statusCode)
        default: return .badRequest(message)
        }
    }

    static func rejectsFallback(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("anthropic-beta") || lowered.contains("fallback")
    }

    private func perform(_ request: AIRequest, config: AIConfiguration, fallback: Bool) async throws -> AIResponse {
        let urlRequest = try makeURLRequest(request, config: config, fallback: fallback)
        let (data, http) = try await sendMapped(urlRequest)
        guard (200..<300).contains(http.statusCode) else { throw Self.error(for: http, data: data, model: config.model) }
        return try Self.parseResponse(data)
    }

    private func addHeaders(to request: inout URLRequest, config: AIConfiguration, fallback: Bool) {
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(config.apiKey.trimmed, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if fallback { request.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta") }
    }

    /// Sends the request and turns transport failures into `AIError`.
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
