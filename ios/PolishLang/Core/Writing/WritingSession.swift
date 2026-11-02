import Foundation
import Observation

/// State of the writing tab: starting tasks, the open workspace, the ladder and the history (TZ 3, section 4).
@MainActor
@Observable
final class WritingSession {
    enum Route: Hashable {
        case workspace
        case feedback(String)
        case history
    }

    enum Phase: Equatable {
        case idle
        case generating(String)
        case failed(message: String, canRetry: Bool)
        case cooldown(until: Date)
    }

    enum Start: Equatable {
        /// The task of the current step.
        case today
        /// "Тренировка формы".
        case form(WritingForm, topic: String)
        /// "Свой текст": a task from a sample test.
        case own(text: String, words: Int)
    }

    var path: [Route] = []
    private(set) var phase: Phase = .idle
    private(set) var workspace: WorkspaceModel?
    private(set) var lastStart: Start?
    /// A start that would replace a draft with text: the hub asks first (inline, no alert).
    private(set) var pendingStart: Start?
    private(set) var savedDraft: WritingDraft?

    // "Тренировка формы".
    var form: WritingForm = .email
    var topic = ""
    // "Свой текст".
    var ownText = ""
    var ownWords = 120

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private let ai: AIService
    @ObservationIgnored private let cards: CardStore
    @ObservationIgnored private let mistakes: MistakeStore
    @ObservationIgnored private let store: WritingStore
    @ObservationIgnored private let errors: TextErrorStore
    @ObservationIgnored private let drafts: WritingDraftStore
    @ObservationIgnored private let photos: PhotoStore
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let toasts: ToastCenter

    init(ai: AIService, cards: CardStore, mistakes: MistakeStore, store: WritingStore, errors: TextErrorStore,
         drafts: WritingDraftStore, photos: PhotoStore, settings: AppSettings, toasts: ToastCenter) {
        self.ai = ai
        self.cards = cards
        self.mistakes = mistakes
        self.store = store
        self.errors = errors
        self.drafts = drafts
        self.photos = photos
        self.settings = settings
        self.toasts = toasts
        savedDraft = drafts.load()
    }

    var step: WritingStep {
        settings.writingStep
    }

    var level: ExamLevel {
        settings.writing.examLevel
    }

    var akapitProgress: WritingRules.StepProgress {
        WritingRules.akapitProgress(store.texts)
    }

    var traps: [TextErrorEntry] {
        errors.traps()
    }

    var isGenerating: Bool {
        if case .generating = phase { return true }
        return false
    }

    /// The step can be used: Akapit always, Egzamin when opened by progress or early.
    func isOpen(_ step: WritingStep) -> Bool {
        step == .akapit || settings.egzaminUnlocked
    }

    /// "Сделать текущей" or "Открыть досрочно".
    func choose(_ step: WritingStep) {
        if step == .egzamin { settings.egzaminUnlocked = true }
        settings.writingStep = step
    }

    // MARK: Starting a task

    func start(_ start: Start) {
        guard !isGenerating else { return }
        if case .cooldown(let until) = phase, until > Date() { return }
        if let draft = unsavedDraft, !draft.text.trimmed.isEmpty || draft.transcript != nil, pendingStart != start {
            pendingStart = start
            return
        }
        pendingStart = nil
        lastStart = start
        if let wait = ai.acquireGenerationSlot() {
            phase = .cooldown(until: Date().addingTimeInterval(wait))
            return
        }
        phase = .generating(label(for: start))
        task = Task { await self.generate(start) }
    }

    /// The text being written: the open workspace before its check, or the draft of an earlier launch.
    var unsavedDraft: WritingDraft? {
        if let workspace, workspace.result == nil { return workspace.draft }
        return savedDraft
    }

    /// The draft is dropped and the waiting start goes on.
    func confirmPendingStart() {
        guard let start = pendingStart else { return }
        discardDraft()
        self.start(start)
    }

    func cancelPendingStart() {
        pendingStart = nil
    }

    func retry() {
        if let lastStart { start(lastStart) }
    }

    func stop() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    func clearFailure() {
        if case .failed = phase { phase = .idle }
    }

    /// Waits for the running generation (used by tests).
    func waitForGeneration() async {
        await task?.value
    }

    func resumeDraft() {
        guard let draft = savedDraft else { return }
        open(makeWorkspace(mode: draft.mode, task: draft.task, draft: draft))
    }

    func discardDraft() {
        drafts.clear()
        savedDraft = nil
        if workspace?.result == nil { workspace = nil }
    }

    /// Back to the open workspace from the hub.
    func showWorkspace() {
        guard workspace != nil else { return }
        if path.last != .workspace { path.append(.workspace) }
    }

    func openText(id: String) {
        path.append(.feedback(id))
    }

    /// "Добавить в карточки": the words keep the form from the feedback (TZ 3, criterion 9).
    func addToCards(_ words: [NewWord]) -> DraftSaveResult {
        let drafts = words.map { CardDraft(entry: ParsedEntry(pl: $0.pl, base: $0.base, ru: $0.ru), source: .writing) }
        let result = DraftBuilder.save(drafts, existingKeys: cards.dedupKeys, photoId: nil)
        cards.add(result.cards)
        return result
    }

    private func label(for start: Start) -> String {
        switch start {
        case .today: return step == .akapit ? "Готовлю задание Akapit…" : "Готовлю экзаменационное задание…"
        case .form(let form, _): return "Готовлю задание: \(form.title)…"
        case .own: return "Готовлю опору для твоего задания…"
        }
    }

    private func generate(_ start: Start) async {
        let level = self.level
        var mode: WritingMode = .exam
        var must: [String] = []
        var mustConnectors: [String] = []
        var kind: WritingForm?
        var length: TaskLength?
        let words: Int
        var topic = ""
        let prompt: String
        switch start {
        case .today where step == .akapit:
            mode = .akapit
            must = MyWordsPicker.pick(from: cards.cards, mistakeCardIDs: mistakes.cardIDs, now: Date(), limit: 5, using: &generator)
            mustConnectors = Array(WritingPrompts.connectors.shuffled(using: &generator).prefix(2))
            words = 65
            prompt = WritingPrompts.task(level: level, form: WritingPrompts.akapitForms, topic: "", words: "50–80", must: must, mustConnectors: mustConnectors)
        case .today:
            let next = settings.nextExamLength
            length = next
            words = settings.writing.words(level, next)
            prompt = WritingPrompts.task(level: level, form: WritingPrompts.examForms(level: level, length: next), topic: "", words: "około \(words)", must: [], mustConnectors: [])
        case .form(let form, let chosenTopic):
            kind = form
            length = form.length
            topic = chosenTopic.collapsingWhitespace
            words = settings.writing.words(level, form.length)
            prompt = WritingPrompts.task(level: level, form: form.promptName, topic: topic, words: "około \(words)", must: [], mustConnectors: [])
        case .own(let text, let count):
            mode = .own
            words = max(20, min(600, count))
            prompt = WritingPrompts.ownTask(text: text, level: level, words: words)
        }
        do {
            var task = try await ai.makeAI().writingTask(prompt: prompt)
            guard !Task.isCancelled else { return }
            if PolishText.containsCyrillic(task.polecenie) || task.punkty.contains(where: PolishText.containsCyrillic) {
                phase = .failed(message: "В польском задании оказалась кириллица.", canRetry: true)
                return
            }
            // The limits of the settings apply to every new task (TZ 3, criterion 10).
            task.words = words
            task.must = must
            task.mustConnectors = mustConnectors
            task.level = level
            task.kind = kind
            task.length = length
            task.topic = topic
            if case .today = start, step == .egzamin {
                settings.nextExamLength = length == .short ? .long : .short
            }
            phase = .idle
            discardDraft()
            open(makeWorkspace(mode: mode, task: task, draft: nil))
        } catch let error as AIError {
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
        case .notConfigured:
            return .failed(message: "Задания готовит AI: добавь API-ключ Claude или Gemini в настройках. Свои тексты и разборы в истории открываются как обычно.", canRetry: false)
        case .refusal:
            return .failed(message: "Не получилось подготовить задание. Попробуй другую тему или формулировку.", canRetry: false)
        case .dailyLimit, .paymentRequired:
            return .failed(message: error.userMessage, canRetry: false)
        case .invalidResponse, .truncated:
            return .failed(message: "Ответ AI обрезан или пришёл в неверном формате.", canRetry: true)
        default:
            return .failed(message: error.userMessage, canRetry: true)
        }
    }

    private func makeWorkspace(mode: WritingMode, task: WritingTask, draft: WritingDraft?) -> WorkspaceModel {
        let model = WorkspaceModel(mode: mode, task: task, draft: draft, ai: ai, store: store, errors: errors, drafts: drafts, photos: photos, settings: settings)
        model.onSaved = { [weak self] text in self?.finished(text) }
        return model
    }

    private func open(_ model: WorkspaceModel) {
        workspace = model
        savedDraft = nil
        model.saveDraftNow()
        path = [.workspace]
    }

    /// After a check: the feedback replaces the workspace, and the ladder may move on.
    private func finished(_ text: WritingText) {
        savedDraft = nil
        path = [.feedback(text.id)]
        if text.mode == .akapit, !settings.egzaminUnlocked, akapitProgress.met {
            settings.egzaminUnlocked = true
            settings.writingStep = .egzamin
            toasts.show("Открыта ступень Egzamin: задания экзамена от руки", seconds: 4)
        }
    }
}
