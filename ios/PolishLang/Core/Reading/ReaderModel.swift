import Foundation
import Observation

/// State of one open text: selection, phrase mode, the translation panel and highlights (TZ 2, section 5).
@MainActor
@Observable
final class ReaderModel {
    enum TranslationState: Equatable {
        case idle
        case loading
        case loaded(WordTranslation)
        case failed(message: String, retryAfter: Date?)
    }

    enum BaseFormState: Equatable {
        case idle
        case loading
        case loaded(EnrichResult)
        case failed(String)
    }

    let text: ReadingText
    let document: ReaderDocument
    /// Key words of the text (dotted underline).
    let keywordTokens: Set<Int>
    /// The learner's words woven into this text.
    let myWordTokens: Set<Int>
    /// Words the learner already has in her cards (always highlighted).
    private(set) var knownTokens: Set<Int> = []

    /// Touch phrase mode: a tap on the first word, then a tap on the last one.
    var phraseMode = false {
        didSet { cancelPhrase() }
    }
    private(set) var phraseAnchor: Int?
    /// A phrase picked in phrase mode, waiting for "Перевести фразу".
    private(set) var pendingPhrase: ReaderSelection?
    private(set) var selection: ReaderSelection?
    var panelPresented = false
    private(set) var translation: TranslationState = .idle
    /// "Сохранить начальную форму вместо этой".
    var saveBaseForm = false
    private(set) var baseForm: BaseFormState = .idle

    @ObservationIgnored private var translationTask: Task<Void, Never>?
    @ObservationIgnored private var baseTask: Task<Void, Never>?

    init(text: ReadingText) {
        let document = ReaderDocument(paragraphs: text.paragraphs)
        self.text = text
        self.document = document
        self.keywordTokens = document.occurrences(of: text.keyWords.map(\.form))
        self.myWordTokens = document.occurrences(of: text.usedMyWords)
    }

    func updateKnownWords(_ phrases: [String]) {
        knownTokens = document.occurrences(of: phrases)
    }

    /// Tokens drawn as selected.
    var highlightedTokens: ClosedRange<Int>? {
        if let pendingPhrase { return pendingPhrase.tokenIDs }
        if let phraseAnchor { return phraseAnchor...phraseAnchor }
        return panelPresented ? selection?.tokenIDs : nil
    }

    /// Handles a tap on a word. Returns a selection to translate right away (a plain tap);
    /// in phrase mode the taps only build `pendingPhrase`.
    func tap(tokenID: Int) -> ReaderSelection? {
        guard let token = document.token(id: tokenID), token.isWord else { return nil }
        guard phraseMode else { return document.selection(from: tokenID, to: tokenID) }
        if let anchor = phraseAnchor, let phrase = document.selection(from: anchor, to: tokenID) {
            phraseAnchor = nil
            pendingPhrase = phrase
        } else {
            // First tap, or the second one landed in another paragraph: start again from here.
            phraseAnchor = tokenID
            pendingPhrase = nil
        }
        return nil
    }

    func cancelPhrase() {
        phraseAnchor = nil
        pendingPhrase = nil
    }

    func translate(_ selection: ReaderSelection, ai: AIService, session: ReadingSession) {
        translationTask?.cancel()
        baseTask?.cancel()
        self.selection = selection
        cancelPhrase()
        saveBaseForm = false
        baseForm = .idle
        panelPresented = true
        if let cached = session.cachedTranslation(textID: text.id, selection: selection) {
            translation = .loaded(cached)
            return
        }
        guard ai.hasKey else {
            translation = .failed(message: "Перевод недоступен: AI не подключён. Добавь API-ключ Claude в настройках.", retryAfter: nil)
            return
        }
        translation = .loading
        let title = text.title
        let textID = text.id
        translationTask = Task {
            do {
                let result = try await ai.translate(selection: selection.text, sentence: selection.sentence, title: title)
                guard self.selection == selection else { return }
                session.cache(result, textID: textID, selection: selection)
                self.translation = .loaded(result)
            } catch let error as AIError {
                guard error != .cancelled, self.selection == selection else { return }
                self.translation = .failed(message: Self.message(for: error), retryAfter: Self.retryDate(for: error))
            } catch {
                guard self.selection == selection else { return }
                self.translation = .failed(message: error.localizedDescription, retryAfter: nil)
            }
        }
    }

    /// Waits for the running requests (used by tests).
    func waitForRequests() async {
        await translationTask?.value
        await baseTask?.value
    }

    func retry(ai: AIService, session: ReadingSession) {
        if let selection { translate(selection, ai: ai, session: session) }
    }

    func panelClosed() {
        translationTask?.cancel()
        baseTask?.cancel()
        selection = nil
        translation = .idle
        saveBaseForm = false
        baseForm = .idle
    }

    // MARK: Adding to cards

    var loadedTranslation: WordTranslation? {
        if case .loaded(let translation) = translation { return translation }
        return nil
    }

    /// The base form differs from the form in the text, so the switch makes sense.
    var canSaveBaseForm: Bool {
        guard let selection, let translation = loadedTranslation, !translation.base.isEmpty else { return false }
        return PolishText.dedupKey(translation.base) != PolishText.dedupKey(selection.text)
    }

    /// Translation of the base form for the switch (a short extra request through the card pipeline).
    func loadBaseForm(ai: AIService) {
        guard let translation = loadedTranslation, canSaveBaseForm else { return }
        switch baseForm {
        case .loading, .loaded: return
        case .idle, .failed: break
        }
        baseForm = .loading
        let selection = self.selection
        baseTask = Task {
            let outcome = await ai.enrich([EnrichInput(pl: translation.base)])
            guard self.selection == selection else { return }
            if let result = outcome.results.first ?? nil, !result.ru.isEmpty {
                self.baseForm = .loaded(result)
            } else {
                self.baseForm = .failed(outcome.failure?.userMessage ?? "Не получилось перевести начальную форму.")
            }
        }
    }

    /// The card "Добавить в карточки" saves: by default the form exactly as in the text with the
    /// whole sentence as the example; with the switch, the base form (TZ 2, section 5).
    func candidateCard() -> Flashcard? {
        guard let selection, let translation = loadedTranslation else { return nil }
        if saveBaseForm {
            guard case .loaded(let base) = baseForm else { return nil }
            return Flashcard(
                pl: translation.base, ru: base.ru, form: base.form, note: base.note, source: .text,
                example: selection.sentence, exampleRu: translation.sentenceRu, textId: text.id
            )
        }
        let arrow = canSaveBaseForm ? "\(translation.base) → \(selection.text)" : ""
        let note = [arrow, translation.form, translation.alternation].filter { !$0.isEmpty }.joined(separator: ", ")
        return Flashcard(
            pl: selection.text, ru: translation.ru, base: translation.base, form: translation.form,
            alternation: translation.alternation, note: note, source: .text,
            example: selection.sentence, exampleRu: translation.sentenceRu, textId: text.id
        )
    }

    private static func message(for error: AIError) -> String {
        switch error {
        case .rateLimited: return "Подожди минуту: слишком много переводов подряд."
        case .notConfigured, .offline: return "Перевод недоступен: \(error.userMessage)"
        default: return error.userMessage
        }
    }

    private static func retryDate(for error: AIError) -> Date? {
        if case .rateLimited(let wait) = error { return Date().addingTimeInterval(wait ?? 60) }
        return nil
    }
}
