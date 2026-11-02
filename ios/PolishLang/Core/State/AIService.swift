import Foundation
import Observation

/// Access to Claude for the screens: the stored key, the settings, and the local
/// rate limits (TZ 2, section 7: 5 generations and 30 translations a minute).
@MainActor
@Observable
final class AIService {
    private static let keyAccount = "anthropic-api-key"

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let secrets: SecretStore
    @ObservationIgnored private var generationLimiter = RateLimiter(limit: 5)
    @ObservationIgnored private var translationLimiter = RateLimiter(limit: 30)
    @ObservationIgnored var client = AnthropicClient()

    /// A key is saved: AI features are available.
    private(set) var hasKey: Bool

    init(settings: AppSettings, secrets: SecretStore) {
        self.settings = settings
        self.secrets = secrets
        hasKey = !(secrets.read(Self.keyAccount) ?? "").trimmed.isEmpty
    }

    func saveKey(_ key: String) {
        let key = key.trimmed
        guard !key.isEmpty else { return }
        hasKey = secrets.save(key, account: Self.keyAccount)
    }

    func deleteKey() {
        secrets.delete(Self.keyAccount)
        hasKey = false
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

    private func makeAI() throws -> PolishAI {
        guard let key = secrets.read(Self.keyAccount)?.trimmed, !key.isEmpty else { throw AIError.notConfigured }
        let model = settings.model.trimmed
        let url = URL(string: settings.baseURLString.trimmed).flatMap { $0.scheme == nil ? nil : $0 }
        let config = AIConfiguration(
            apiKey: key,
            model: model.isEmpty ? AIConfiguration.defaultModel : model,
            baseURL: url ?? AIConfiguration.defaultBaseURL,
            refusalFallback: settings.refusalFallback
        )
        return PolishAI(client: client, config: config)
    }
}
