import Foundation
import Observation

/// State of the reading tab: the generation form, the current text and the translation cache.
@MainActor
@Observable
final class ReadingSession {
    enum Route: Hashable {
        case reader, history
    }

    enum Phase: Equatable {
        case idle
        case generating(CEFRLevel)
        case failed(message: String, canRetry: Bool)
        /// Too many requests: the button comes back at this moment (TZ 2, section 7).
        case cooldown(until: Date)
    }

    struct Request: Equatable {
        var topic: String
        var level: CEFRLevel
        var kind: TextKind
        var useMyWords: Bool
    }

    // The form.
    var topic = ""
    var kind: TextKind = .default
    var useMyWords = false

    var path: [Route] = []
    private(set) var phase: Phase = .idle
    private(set) var current: ReadingText?
    /// Soft warning about the length of the current text.
    private(set) var warning: String?
    /// How many of the learner's words were asked to be woven into the current text.
    private(set) var requestedMyWords = 0
    private(set) var lastRequest: Request?

    @ObservationIgnored private var task: Task<Void, Never>?
    /// Translations per text id, keyed by (selection, sentence), for the lifetime of the app.
    @ObservationIgnored private var translations: [String: [String: WordTranslation]] = [:]
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private let ai: AIService
    @ObservationIgnored private let cards: CardStore
    @ObservationIgnored private let mistakes: MistakeStore
    @ObservationIgnored private let readings: ReadingStore
    @ObservationIgnored private let settings: AppSettings

    init(ai: AIService, cards: CardStore, mistakes: MistakeStore, readings: ReadingStore, settings: AppSettings) {
        self.ai = ai
        self.cards = cards
        self.mistakes = mistakes
        self.readings = readings
        self.settings = settings
    }

    var isGenerating: Bool {
        if case .generating = phase { return true }
        return false
    }

    var isCurrentSaved: Bool {
        current.map { readings.contains(id: $0.id) } ?? false
    }

    /// From the form.
    func generate() {
        generate(Request(topic: topic, level: settings.readingLevel, kind: kind, useMyWords: useMyWords))
    }

    /// From the reader: "Другой текст" (same level) or "Проще"/"Сложнее" (a neighbouring level).
    func regenerate(level: CEFRLevel? = nil) {
        guard let text = current else { return }
        let useMyWords = lastRequest?.useMyWords ?? self.useMyWords
        generate(Request(topic: text.topic, level: level ?? text.level, kind: text.kind, useMyWords: useMyWords))
    }

    func retry() {
        if let lastRequest { generate(lastRequest) }
    }

    func generate(_ request: Request) {
        var request = request
        request.topic = request.topic.collapsingWhitespace
        guard !request.topic.isEmpty, !isGenerating else { return }
        if case .cooldown(let until) = phase, until > Date() { return }
        lastRequest = request
        phase = .generating(request.level)
        task = Task { await self.run(request) }
    }

    func stop() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    /// Waits for the running generation (used by tests).
    func waitForGeneration() async {
        await task?.value
    }

    func clearFailure() {
        if case .failed = phase { phase = .idle }
    }

    func open(_ text: ReadingText) {
        current = text
        warning = nil
        requestedMyWords = 0
        if path.last != .reader { path.append(.reader) }
    }

    func saveCurrent() {
        if let current { readings.save(current) }
    }

    func cachedTranslation(textID: String, selection: ReaderSelection) -> WordTranslation? {
        translations[textID]?[Self.cacheKey(selection)]
    }

    func cache(_ translation: WordTranslation, textID: String, selection: ReaderSelection) {
        translations[textID, default: [:]][Self.cacheKey(selection)] = translation
    }

    private static func cacheKey(_ selection: ReaderSelection) -> String {
        selection.text + "\u{1F}" + selection.sentence
    }

    private func run(_ request: Request) async {
        let myWords = request.useMyWords
            ? MyWordsPicker.pick(from: cards.cards, mistakeCardIDs: mistakes.cardIDs, now: Date(), using: &generator)
            : []
        do {
            let generated = try await ai.generate(topic: request.topic, kind: request.kind, level: request.level, myWords: myWords)
            guard !Task.isCancelled else { return }
            let check = GenerationValidator.check(generated, level: request.level)
            guard !check.hasCyrillic else {
                phase = .failed(message: "В польском тексте оказалась кириллица.", canRetry: true)
                return
            }
            let text = ReadingText(
                topic: request.topic,
                level: request.level,
                kind: request.kind,
                title: generated.title.isEmpty ? request.topic : generated.title,
                paragraphs: generated.paragraphs,
                keyWords: check.keyWords,
                usedMyWords: check.usedMyWords
            )
            current = text
            warning = check.lengthWarning
            requestedMyWords = myWords.count
            if settings.autosaveTexts { readings.save(text) }
            phase = .idle
            if path.last != .reader { path.append(.reader) }
        } catch let error as AIError {
            // After "Стоп" the phase is already idle.
            guard error != .cancelled else { return }
            phase = Self.phase(for: error)
        } catch {
            phase = .failed(message: error.localizedDescription, canRetry: true)
        }
    }

    static func phase(for error: AIError) -> Phase {
        switch error {
        case .rateLimited(let wait):
            return .cooldown(until: Date().addingTimeInterval(wait ?? 60))
        case .refusal:
            return .failed(message: "Не получилось сгенерировать текст на эту тему. Попробуй другую формулировку.", canRetry: false)
        case .invalidResponse, .truncated:
            return .failed(message: "Ответ AI обрезан или пришёл в неверном формате.", canRetry: true)
        case .notConfigured:
            return .failed(message: "Генерация недоступна: добавь API-ключ Claude в настройках. История и сохранённые тексты читаются как обычно.", canRetry: false)
        case .offline:
            return .failed(message: "Нет подключения к интернету. История и сохранённые тексты читаются как обычно.", canRetry: true)
        default:
            return .failed(message: error.userMessage, canRetry: true)
        }
    }
}
