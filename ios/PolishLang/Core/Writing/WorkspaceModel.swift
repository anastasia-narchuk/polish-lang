import Foundation
import Observation

/// One task at work: the text, the support, the photos and the check (TZ 3, 4.2 and section 6).
@MainActor
@Observable
final class WorkspaceModel: Identifiable {
    enum Phase: Equatable {
        case writing
        case transcribing
        /// The learner fixes what was misread (not her own mistakes) before the check.
        case reviewingTranscript
        case checking
        case failed(message: String, canRetry: Bool)
    }

    let id = UUID()
    let mode: WritingMode
    let task: WritingTask
    let started: Date

    var text: String {
        didSet { if text != oldValue { scheduleSave() } }
    }
    /// "Pomysły": ideas in Russian before writing; not checked, kept with the text.
    var ideasDraft: String {
        didSet { if ideasDraft != oldValue { scheduleSave() } }
    }
    /// "От руки · фото" instead of typing.
    var hand: Bool {
        didSet { if hand != oldValue { scheduleSave() } }
    }
    var transcript: String {
        didSet { if transcript != oldValue { scheduleSave() } }
    }
    var checklist: WritingChecklist {
        didSet { scheduleSave() }
    }
    /// The support panel is shown now. Showing it once is enough for "с опорой".
    var supportShown: Bool {
        didSet { if supportShown { support.opened = true } }
    }
    var translationShown = false
    private(set) var photos: [Data]
    private(set) var support: SupportStats
    private(set) var revealedIdeas: Set<Int>
    private(set) var phase: Phase = .writing
    /// The saved check; the screen opens the feedback.
    private(set) var result: WritingText?

    @ObservationIgnored var onSaved: ((WritingText) -> Void)?
    @ObservationIgnored private var task_: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var lastAction: (@MainActor () -> Void)?
    @ObservationIgnored private let ai: AIService
    @ObservationIgnored private let store: WritingStore
    @ObservationIgnored private let errors: TextErrorStore
    @ObservationIgnored private let drafts: WritingDraftStore
    @ObservationIgnored private let photoStore: PhotoStore
    @ObservationIgnored private let settings: AppSettings

    init(
        mode: WritingMode, task: WritingTask, draft: WritingDraft? = nil,
        ai: AIService, store: WritingStore, errors: TextErrorStore, drafts: WritingDraftStore, photos: PhotoStore, settings: AppSettings
    ) {
        self.mode = mode
        self.task = task
        self.ai = ai
        self.store = store
        self.errors = errors
        self.drafts = drafts
        self.photoStore = photos
        self.settings = settings
        let policy = SupportPolicy.of(mode: mode, hand: draft?.hand ?? (mode == .exam))
        started = draft?.started ?? Date()
        text = draft?.text ?? ""
        ideasDraft = draft?.ideasDraft ?? ""
        // Egzamin is written by hand; typing is the training mode of the other steps.
        hand = draft?.hand ?? (mode == .exam)
        transcript = draft?.transcript ?? ""
        checklist = draft?.checklist ?? WritingChecklist()
        revealedIdeas = Set(draft?.revealedIdeas ?? [])
        var stats = draft?.support ?? SupportStats()
        stats.ideasTotal = task.ideas.count
        if policy.startsOpen { stats.opened = true }
        support = stats
        supportShown = policy.startsOpen
        // Photos stay in memory until the check; the transcript is kept in the draft.
        self.photos = []
        if !transcript.isEmpty { phase = .reviewingTranscript }
    }

    var policy: SupportPolicy {
        SupportPolicy.of(mode: mode, hand: hand)
    }

    var lettersBarShown: Bool {
        policy.lettersBar && settings.writing.lettersBar
    }

    /// The text that goes to the check: typed, or the confirmed transcript.
    var currentText: String {
        hand ? transcript : text
    }

    var wordCount: Int {
        PolishText.wordCount(currentText)
    }

    var range: ClosedRange<Int> {
        WritingRules.range(for: task, mode: mode)
    }

    var lengthStatus: LengthStatus {
        WritingRules.lengthStatus(count: wordCount, range: range)
    }

    /// Required words and connectors already used in any form.
    var usedChips: Set<String> {
        Set((task.must + task.mustConnectors).filter { WritingRules.isUsed($0, in: currentText) })
    }

    var isWorking: Bool {
        phase == .transcribing || phase == .checking
    }

    var canCheck: Bool {
        guard !isWorking else { return false }
        if hand, phase != .reviewingTranscript { return !photos.isEmpty }
        return wordCount >= WritingRules.minimumWords
    }

    /// Share of unreadable words in the transcript; above 15% the photo should be retaken.
    var unreadableShare: Double {
        let words = transcript.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return 0 }
        return Double(words.filter { $0.contains("[?]") }.count) / Double(words.count)
    }

    var seconds: Int {
        max(0, Int(Date().timeIntervalSince(started)))
    }

    // MARK: Support

    func toggleSupport() {
        supportShown.toggle()
    }

    /// Ideas show the Russian thought; a tap opens the Polish collocation and is counted.
    func revealIdea(_ index: Int) {
        guard task.ideas.indices.contains(index), !revealedIdeas.contains(index) else { return }
        revealedIdeas.insert(index)
        support.ideasRevealed = revealedIdeas.count
        scheduleSave()
    }

    // MARK: Photos

    func addPhotos(_ jpegs: [Data]) {
        let room = max(0, PolishAI.maxPhotos - photos.count)
        photos += jpegs.prefix(room)
        resetTranscript()
    }

    func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
        resetTranscript()
    }

    func replacePhoto(at index: Int, with data: Data) {
        guard photos.indices.contains(index) else { return }
        photos[index] = data
        resetTranscript()
    }

    /// Pages in the wrong order can be moved before the transcription (TZ 3, section 12).
    func movePhoto(from index: Int, by offset: Int) {
        let target = index + offset
        guard photos.indices.contains(index), photos.indices.contains(target) else { return }
        photos.swapAt(index, target)
        resetTranscript()
    }

    private func resetTranscript() {
        transcript = ""
        if phase == .reviewingTranscript { phase = .writing }
    }

    // MARK: Check

    /// "Разобрать с коучем": typed text goes to the check; photos are read first and the
    /// transcript is shown for confirmation.
    func check() {
        guard canCheck else { return }
        if hand && phase != .reviewingTranscript {
            run { await self.transcribe() }
        } else {
            let text = currentText
            run { await self.runCheck(text: text) }
        }
    }

    func retry() {
        lastAction?()
    }

    func stop() {
        task_?.cancel()
        task_ = nil
        phase = hand && !transcript.isEmpty ? .reviewingTranscript : .writing
    }

    /// Waits for the running request (used by tests).
    func waitForWork() async {
        await task_?.value
    }

    private func run(_ work: @escaping @MainActor () async -> Void) {
        let action: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            self.task_ = Task { await work() }
        }
        lastAction = action
        action()
    }

    private func transcribe() async {
        phase = .transcribing
        do {
            let ai = try self.ai.makeAI()
            let images = photos.map { AIImage(mediaType: "image/jpeg", data: $0) }
            let text = try await ai.transcribe(images: images)
            guard !Task.isCancelled else { return }
            transcript = text
            phase = .reviewingTranscript
            saveDraftNow()
        } catch {
            fail(error, stage: "Не получилось прочитать рукопись.")
        }
    }

    private func runCheck(text: String) async {
        phase = .checking
        saveDraftNow()
        do {
            let ai = try self.ai.makeAI()
            var check = try await ai.checkText(task: task, text: text)
            guard !Task.isCancelled else { return }
            check = WritingRules.applyGuards(check, text: text)
            let percent = check.scores.percent
            let weight = mode == .exam ? settings.writing.weight(task.length ?? .long) : nil
            let photoId = hand && !photos.isEmpty ? photoStore.save(photos) : nil
            let record = WritingText(
                id: UUID().uuidString,
                created: Date(),
                mode: mode,
                step: mode == .akapit ? .akapit : (mode == .exam ? .egzamin : nil),
                examLevel: task.level,
                task: task,
                ideasDraft: ideasDraft,
                text: text,
                hand: hand,
                photoId: photoId,
                seconds: seconds,
                support: support,
                checklist: checklist,
                result: check,
                score: percent,
                taskPoints: weight.map { WritingRules.taskPoints(percent: percent, weight: $0) },
                taskWeight: weight
            )
            store.save(record)
            errors.record(check, source: mode.rawValue)
            saveTask?.cancel()
            drafts.clear()
            result = record
            phase = .writing
            onSaved?(record)
        } catch {
            fail(error, stage: "Разбор не получился.")
        }
    }

    private func fail(_ error: Error, stage: String) {
        let aiError = error as? AIError ?? .network(error.localizedDescription)
        guard aiError != .cancelled else { return }
        switch aiError {
        case .notConfigured:
            phase = .failed(message: "Проверка недоступна: добавь API-ключ Claude или Gemini в настройках. Писать и сохранять черновик можно.", canRetry: false)
        case .offline:
            phase = .failed(message: "Нет подключения к интернету. Черновик сохранён — проверь, когда появится сеть.", canRetry: true)
        case .dailyLimit, .paymentRequired:
            phase = .failed(message: aiError.userMessage, canRetry: false)
        default:
            phase = .failed(message: "\(stage) \(aiError.userMessage) Черновик сохранён.", canRetry: true)
        }
    }

    // MARK: Draft

    var draft: WritingDraft {
        WritingDraft(
            mode: mode, task: task, text: text, ideasDraft: ideasDraft, hand: hand, started: started,
            support: support, revealedIdeas: revealedIdeas.sorted(), checklist: checklist,
            transcript: transcript.isEmpty ? nil : transcript, photoId: nil
        )
    }

    func saveDraftNow() {
        saveTask?.cancel()
        drafts.save(draft)
    }

    /// Saves 2 s after the last change.
    private func scheduleSave() {
        guard result == nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveDraftNow()
        }
    }
}
