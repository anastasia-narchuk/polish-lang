import Foundation
import Observation

/// Access to the AI for the screens: the chosen provider (Claude or Gemini), its stored key,
/// the settings, and the local rate limits (TZ 2, section 7: 5 generations and 30 translations a minute).
@MainActor
@Observable
final class AIService {
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let secrets: SecretStore
    @ObservationIgnored private var generationLimiter = RateLimiter(limit: 5)
    @ObservationIgnored private var translationLimiter = RateLimiter(limit: 30)
    @ObservationIgnored var client = AnthropicClient()
    @ObservationIgnored var geminiClient = GeminiClient()

    /// Providers with a saved key.
    private(set) var savedKeys: Set<AIProvider>

    init(settings: AppSettings, secrets: SecretStore) {
        self.settings = settings
        self.secrets = secrets
        savedKeys = Set(AIProvider.allCases.filter { !(secrets.read($0.keyAccount) ?? "").trimmed.isEmpty })
    }

    /// The chosen provider has a key: AI features are available.
    var hasKey: Bool {
        savedKeys.contains(settings.provider)
    }

    var provider: AIProvider {
        settings.provider
    }

    func hasKey(for provider: AIProvider) -> Bool {
        savedKeys.contains(provider)
    }

    /// Saves the key of the chosen provider.
    func saveKey(_ key: String) {
        saveKey(key, for: settings.provider)
    }

    func saveKey(_ key: String, for provider: AIProvider) {
        let key = key.trimmed
        guard !key.isEmpty else { return }
        if secrets.save(key, account: provider.keyAccount) {
            savedKeys.insert(provider)
        } else {
            savedKeys.remove(provider)
        }
    }

    func deleteKey() {
        deleteKey(for: settings.provider)
    }

    func deleteKey(for provider: AIProvider) {
        secrets.delete(provider.keyAccount)
        savedKeys.remove(provider)
    }

    func generate(topic: String, kind: TextKind, level: CEFRLevel, myWords: [String]) async throws -> GeneratedText {
        let ai = try makeAI()
        if let wait = generationLimiter.acquire() { throw AIError.rateLimited(retryAfter: wait) }
        return try await ai.generate(topic: topic, kind: kind, level: level, myWords: myWords)
    }

    func translate(selection: String, sentence: String, title: String) async throws -> WordTranslation {
        let ai = try makeAI()
        if let wait = translationLimiter.acquire() { throw AIError.rateLimited(retryAfter: wait) }
        return try await ai.translate(selection: selection, sentence: sentence, title: title)
    }

    func enrich(_ inputs: [EnrichInput]) async -> EnrichOutcome {
        do {
            return try await makeAI().enrich(inputs)
        } catch {
            return EnrichOutcome(results: Array(repeating: nil, count: inputs.count), failure: error as? AIError ?? .notConfigured)
        }
    }

    func recognize(images: [AIImage], mode: PhotoMode) async throws -> [PhotoItem] {
        try await makeAI().recognize(images: images, mode: mode)
    }

    func checkConnection() async throws {
        let ai = try makeAI()
        try await ai.client.checkConnection(config: ai.config)
    }

    /// The operations with the chosen provider, its key and model. Writing (TZ 3) uses it too.
    func makeAI() throws -> PolishAI {
        let provider = settings.provider
        guard let key = secrets.read(provider.keyAccount)?.trimmed, !key.isEmpty else { throw AIError.notConfigured }
        switch provider {
        case .claude:
            let model = settings.model.trimmed
            let url = URL(string: settings.baseURLString.trimmed).flatMap { $0.scheme == nil ? nil : $0 }
            let config = AIConfiguration(
                apiKey: key,
                provider: .claude,
                model: model.isEmpty ? AIConfiguration.defaultModel : model,
                baseURL: url ?? AIConfiguration.defaultBaseURL,
                refusalFallback: settings.refusalFallback
            )
            return PolishAI(client: client, config: config)
        case .gemini:
            let model = settings.geminiModel.trimmed
            let config = AIConfiguration(
                apiKey: key,
                provider: .gemini,
                model: model.isEmpty ? GeminiClient.defaultModel : model,
                baseURL: GeminiClient.defaultBaseURL,
                refusalFallback: false,
                overloadFallbackModel: settings.geminiFallback ? GeminiClient.fallbackModel : nil
            )
            return PolishAI(client: geminiClient, config: config)
        }
    }

    /// A generation slot of the local limit (5 a minute); nil when allowed, otherwise the seconds to wait.
    func acquireGenerationSlot() -> TimeInterval? {
        generationLimiter.acquire()
    }
}
