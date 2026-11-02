import SwiftUI

/// The writing practice for the written part of the exam (TZ 3).
struct WritingTab: View {
    @Environment(WritingSession.self) private var session

    var body: some View {
        @Bindable var session = session
        NavigationStack(path: $session.path) {
            WritingHubView()
                .navigationTitle("Письмо")
                .navigationDestination(for: WritingSession.Route.self) { route in
                    switch route {
                    case .workspace: WorkspaceScreen()
                    case .feedback(let id): FeedbackScreen(id: id)
                    case .history: WritingHistoryView()
                    }
                }
        }
    }
}

/// The hub (TZ 3, 4.1): the task of today's step, form training, an own task, traps and the texts.
struct WritingHubView: View {
    @Environment(AppModel.self) private var app
    @Environment(WritingSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(AIService.self) private var ai
    @Environment(WritingStore.self) private var texts
    @Environment(TextErrorStore.self) private var textErrors
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case topic, own
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                if session.pendingStart != nil {
                    pendingBanner
                }
                statusSection
                continueSection
                todayCard
                formSection
                ownSection
                if !textErrors.entries.isEmpty {
                    trapsSection
                }
                historySection
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Status

    private var pendingBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Banner(text: "Есть начатый текст. Новое задание удалит черновик.", style: .warning)
            HStack(spacing: 8) {
                Button("Начать новое") { session.confirmPendingStart() }
                    .buttonStyle(.pill(.destructive, size: .medium))
                Button("Продолжить черновик") {
                    session.cancelPendingStart()
                    continueWriting()
                }
                .buttonStyle(.pill(.secondary, size: .medium))
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch session.phase {
        case .generating(let label):
            WorkingRow(text: label) { session.stop() }
                .padding(16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        case .failed(let message, let canRetry):
            VStack(alignment: .leading, spacing: 8) {
                Banner(text: message, style: .error)
                HStack(spacing: 8) {
                    if canRetry {
                        Button("Ещё раз") { session.retry() }
                            .buttonStyle(.pill(.secondary, size: .medium))
                    }
                    Button("Скрыть") { session.clearFailure() }
                        .buttonStyle(.pill(.tertiary, size: .medium))
                }
            }
        case .cooldown(let until):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let wait = max(0, Int(until.timeIntervalSince(context.date).rounded(.up)))
                if wait > 0 {
                    Banner(text: "Подожди минуту: слишком много заданий подряд. Можно снова через \(wait) с.", style: .warning)
                }
            }
        case .idle:
            EmptyView()
        }
        if !ai.hasKey {
            VStack(alignment: .leading, spacing: 12) {
                Banner(text: "Задания и разбор готовит AI: добавь API-ключ Claude или Gemini в настройках. Разборы в истории открываются и без него.", style: .info)
                Button("Открыть настройки") { app.tab = .settings }
                    .buttonStyle(.pill(.secondary, size: .medium))
            }
        }
    }

    @ViewBuilder
    private var continueSection: some View {
        if let draft = session.unsavedDraft {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Черновик")
                Button(action: continueWriting) {
                    InfoRow(icon: "pencil.line", title: draft.task.polecenie, subtitle: draftLine(draft)) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func draftLine(_ draft: WritingDraft) -> String {
        let words = PolishText.wordCount(draft.hand ? (draft.transcript ?? "") : draft.text)
        return "\(Russian.words(words)) · \(draft.hand ? "от руки" : "печатаю") · начато \(draft.started.formatted(date: .abbreviated, time: .shortened))"
    }

    private func continueWriting() {
        if session.workspace != nil {
            session.showWorkspace()
        } else {
            session.resumeDraft()
        }
    }

    // MARK: Today

    private var todayCard: some View {
        FeatureCard(feature: Theme.writingFeature, title: "Сегодня") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Tag(text: "Ступень \(session.step.title)", style: .accent)
                    Tag(text: session.level.rawValue, style: .neutral)
                }
                Text(session.step.summary)
                    .font(.ui(.body))
                    .fixedSize(horizontal: false, vertical: true)
            }
            stepDetails
            Button {
                session.start(.today)
            } label: {
                Label(session.step == .akapit ? "Начать абзац" : "Начать задание", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.primary))
            .disabled(!ai.hasKey || session.isGenerating)
            stepSwitcher
        }
    }

    @ViewBuilder
    private var stepDetails: some View {
        if session.step == .akapit {
            let progress = session.akapitProgress
            VStack(alignment: .leading, spacing: 8) {
                ProgressBar(value: progress.fraction, tint: Theme.writingFeature.accent, track: Color.white.opacity(0.16))
                Text("До ступени Egzamin: " + progress.text)
                    .font(.ui(.footnote))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            let length = settings.nextExamLength
            Text("Следующее: \(length.title), ≈\(settings.writing.words(session.level, length)) слов, лучше от руки. Опора скрыта, как на экзамене.")
                .font(.ui(.footnote))
                .foregroundStyle(Color.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(WritingStep.allCases) { step in
                Button {
                    session.choose(step)
                } label: {
                    HStack(spacing: 6) {
                        Text(step.title)
                        if !session.isOpen(step) {
                            Text("досрочно")
                                .font(.ui(.caption, weight: .semibold))
                                .opacity(0.7)
                        }
                    }
                }
                .buttonStyle(ChipButtonStyle(isSelected: session.step == step))
                .accessibilityAddTraits(session.step == step ? .isSelected : [])
            }
        }
    }

    // MARK: Form training

    private var formSection: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Тренировка формы")
            Text("Задание экзамена в выбранной форме, объём — из настроек. Опора скрыта: её можно открыть, но текст будет отмечен «с опорой».")
                .font(.ui(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(WritingForm.allCases) { form in
                    Button(form.title) { session.form = form }
                        .buttonStyle(ChipButtonStyle(isSelected: session.form == form))
                }
            }
            Text("Тема")
                .font(.ui(.footnote, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ReadingTopics.quick, id: \.self) { topic in
                    Button(topic) {
                        session.topic = session.topic == topic ? "" : topic
                        focus = nil
                    }
                    .buttonStyle(ChipButtonStyle(isSelected: session.topic == topic))
                }
            }
            TextField("Своя тема (необязательно)", text: $session.topic)
                .focused($focus, equals: .topic)
                .submitLabel(.done)
                .fieldBackground(isFocused: focus == .topic)
            Button {
                focus = nil
                session.start(.form(session.form, topic: session.topic))
            } label: {
                Label("Создать задание · \(session.form.length.title)", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.secondary))
            .disabled(!ai.hasKey || session.isGenerating)
        }
    }

    // MARK: Own task

    private var ownSection: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Свой текст")
            Text("Вставь задание из пробного теста — по-польски или по-русски. AI выделит пункты и подготовит опору.")
                .font(.ui(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Napisz e-mail do sąsiada z prośbą o pomoc przy przeprowadzce…", text: $session.ownText, axis: .vertical)
                .lineLimit(3...8)
                .focused($focus, equals: .own)
                .textInputAutocapitalization(.sentences)
                .fieldBackground(isFocused: focus == .own)
            Stepper(value: $session.ownWords, in: 20...600, step: 10) {
                Text("Объём: \(Russian.words(session.ownWords))")
                    .font(.ui(.body))
            }
            Button {
                focus = nil
                session.start(.own(text: session.ownText, words: session.ownWords))
            } label: {
                Label("Начать", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.secondary))
            .disabled(!ai.hasKey || session.isGenerating || session.ownText.trimmed.isEmpty)
        }
    }

    // MARK: Traps and texts

    private var trapsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Мои ловушки")
            ForEach(textErrors.traps()) { trap in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Theme.warning)
                        .accessibilityHidden(true)
                    Text(trap.trapLine)
                        .font(Theme.polish(.body))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text("×\(trap.count)")
                        .font(.ui(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Мои тексты") {
                if !texts.texts.isEmpty {
                    Button("Все тексты") { session.path.append(.history) }
                        .buttonStyle(.pill(.secondary, size: .small))
                }
            }
            .padding(.bottom, 8)
            if texts.texts.isEmpty {
                Text("Пока нет текстов — начни с задания «Akapit». Здесь появятся проверенные тексты с баллами и ошибками.")
                    .font(.ui(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(texts.texts.prefix(3).enumerated()), id: \.element.id) { index, text in
                if index > 0 {
                    Hairline()
                }
                Button {
                    session.openText(id: text.id)
                } label: {
                    WritingTextRow(text: text)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A checked text: score, form, date and badges (TZ 3, 4.7).
struct WritingTextRow: View {
    let text: WritingText

    var body: some View {
        HStack(spacing: 16) {
            Text("\(text.score)%")
                .font(.ui(.headline, weight: .bold))
                .foregroundStyle(text.passed ? Theme.positive : Theme.negative)
                .frame(width: 56, height: 48)
                .background(text.passed ? Theme.positiveFill : Theme.negativeFill, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(text.task.polecenie)
                    .font(.ui(.headline))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(meta)
                    .font(.ui(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if text.hand {
                        Tag(text: "от руки", style: .positive)
                    }
                    if text.support.opened {
                        Tag(text: "с опорой", style: .warning)
                    }
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var meta: String {
        var parts: [String] = []
        switch text.mode {
        case .akapit: parts.append("Akapit")
        case .exam: parts.append(text.task.kind?.title ?? text.task.form)
        case .own: parts.append("свой текст")
        }
        parts.append(text.examLevel.rawValue)
        parts.append(text.created.formatted(date: .abbreviated, time: .omitted))
        parts.append(Russian.words(text.wordCount))
        return parts.joined(separator: " · ")
    }
}

/// All checked texts; swipe and "Удалить" deletes (two taps, no alert).
struct WritingHistoryView: View {
    @Environment(AppModel.self) private var app
    @Environment(WritingStore.self) private var texts
    @Environment(WritingSession.self) private var session

    var body: some View {
        List {
            ForEach(texts.texts) { text in
                Button {
                    session.openText(id: text.id)
                } label: {
                    WritingTextRow(text: text)
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.background)
                .listRowSeparatorTint(Theme.line)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.screen, bottom: 0, trailing: Theme.Space.screen))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        app.deleteWritingText(id: text.id)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Мои тексты")
        .overlay {
            if texts.texts.isEmpty {
                EmptyState(icon: "doc.text.magnifyingglass", title: "Пока нет текстов", text: "Начни с задания «Akapit» — разбор появится здесь.")
            }
        }
    }
}
