import Foundation

/// Who answers the app's AI requests. The prompts, schemas and parsing are the same for both.
enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude, gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        }
    }

    /// Keychain account of the provider's API key.
    var keyAccount: String {
        switch self {
        case .claude: return "anthropic-api-key"
        case .gemini: return "gemini-api-key"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return AIConfiguration.defaultModel
        case .gemini: return GeminiClient.defaultModel
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AIProvider(rawValue: raw) ?? .claude
    }
}

/// A Messages-style backend: one request in, the text of the reply out.
protocol AIBackend: Sendable {
    func send(_ request: AIRequest, config: AIConfiguration) async throws -> AIResponse
    /// Checks the key and the model with as little spending as the provider allows.
    func checkConnection(config: AIConfiguration) async throws
}

extension AnthropicClient: AIBackend {}
