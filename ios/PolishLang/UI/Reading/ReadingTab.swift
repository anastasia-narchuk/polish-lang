import SwiftUI

struct ReadingTab: View {
    @Environment(ReadingSession.self) private var session

    var body: some View {
        @Bindable var session = session
        NavigationStack(path: $session.path) {
            ReadingSetupView()
                .navigationTitle("Чтение")
                .navigationDestination(for: ReadingSession.Route.self) { route in
                    switch route {
                    case .reader: ReaderScreen()
                    case .history: ReadingHistoryView()
                    }
                }
        }
    }
}

/// Topic, level and options of a new text (TZ 2, section 2).
struct ReadingSetupView: View {
    @Environment(AppModel.self) private var app
    @Environment(ReadingSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(AIService.self) private var ai
    @Environment(CardStore.self) private var cards
    @Environment(ReadingStore.self) private var readings
    @State private var showAdvanced = false
    @FocusState private var topicFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topicSection
                levelSection
                advancedSection
                generateSection
                if !readings.texts.isEmpty {
                    historySection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var topicSection: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 12) {
            Text("Тема")
                .font(.headline)
            TextField("Например: wizyta u lekarza или «поиск квартиры»", text: $session.topic)
                .font(Theme.polish(.title3))
                .submitLabel(.go)
                .focused($topicFocused)
                .onSubmit(generate)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ReadingTopics.quick, id: \.self) { topic in
                    Button(topic) {
                        session.topic = topic
                        topicFocused = false
                    }
                    .buttonStyle(ChipButtonStyle(isSelected: session.topic == topic))
                }
            }
        }
    }

    private var levelSection: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 10) {
            Text("Уровень")
                .font(.headline)
            Picker("Уровень", selection: $settings.readingLevel) {
                ForEach(CEFRLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            Text(settings.readingLevel.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var advancedSection: some View {
        @Bindable var session = session
        return DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Тип текста")
                    Spacer()
                    Picker("Тип текста", selection: $session.kind) {
                        ForEach(TextKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Toggle("Используй мои слова", isOn: $session.useMyWords)
                    .disabled(cards.cards.isEmpty)
                Text(cards.cards.isEmpty
                    ? "Когда появятся карточки, в текст можно будет вплести 5–8 твоих слов."
                    : "В текст попадут 5–8 слов из карточек: сначала недавние и те, в которых были ошибки.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
        } label: {
            Text("Дополнительно")
                .font(.headline)
                .foregroundStyle(Color.primary)
        }
        .cardBackground()
    }

    @ViewBuilder
    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch session.phase {
            case .generating(let level):
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Пишу текст уровня \(level.rawValue)…")
                    Spacer()
                    Button("Стоп", role: .cancel) { session.stop() }
                        .buttonStyle(.bordered)
                }
                .cardBackground()
            case .failed(let message, let canRetry):
                Banner(text: message, style: .error)
                if canRetry {
                    Button("Ещё раз") { session.retry() }
                        .buttonStyle(.bordered)
                }
                generateButton(enabled: canGenerate)
            case .cooldown(let until):
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let wait = max(0, Int(until.timeIntervalSince(context.date).rounded(.up)))
                    VStack(alignment: .leading, spacing: 12) {
                        if wait > 0 {
                            Banner(text: "Подожди минуту: слишком много текстов подряд. Можно снова через \(wait) с.", style: .warning)
                        }
                        generateButton(enabled: canGenerate && wait == 0)
                    }
                }
            case .idle:
                generateButton(enabled: canGenerate)
            }
            if !ai.hasKey {
                Banner(text: "Генерация недоступна: добавь API-ключ Claude в настройках. История и сохранённые тексты читаются как обычно.", style: .info)
                Button("Открыть настройки") { app.tab = .settings }
                    .buttonStyle(.bordered)
            } else if session.topic.trimmed.isEmpty {
                Text("Введи тему или выбери чип")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func generateButton(enabled: Bool) -> some View {
        Button(action: generate) {
            Label("Сгенерировать", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!enabled)
    }

    private var canGenerate: Bool {
        ai.hasKey && !session.topic.trimmed.isEmpty && !session.isGenerating
    }

    private func generate() {
        guard canGenerate else { return }
        topicFocused = false
        session.generate()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("История")
                    .font(.headline)
                Spacer()
                Button("Все тексты") { session.path.append(.history) }
            }
            ForEach(readings.texts.prefix(3)) { text in
                Button {
                    session.open(text)
                } label: {
                    HistoryRow(text: text)
                        .cardBackground()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HistoryRow: View {
    let text: ReadingText

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(text.title)
                    .font(Theme.polish(.headline))
                    .lineLimit(2)
                Spacer(minLength: 8)
                LevelBadge(level: text.level)
            }
            HStack(spacing: 6) {
                Text(text.topic)
                Text("·")
                Text(text.created, format: .dateTime.day().month().year())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// History of texts: tap opens the reader, swipe and "Удалить" deletes (two taps, no alert).
struct ReadingHistoryView: View {
    @Environment(ReadingStore.self) private var readings
    @Environment(ReadingSession.self) private var session

    var body: some View {
        List {
            ForEach(readings.texts) { text in
                Button {
                    session.open(text)
                } label: {
                    HistoryRow(text: text)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        readings.delete(id: text.id)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("История")
        .overlay {
            if readings.texts.isEmpty {
                ContentUnavailableView(
                    "Пока пусто",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Сохранённые тексты появятся здесь.")
                )
            }
        }
    }
}
