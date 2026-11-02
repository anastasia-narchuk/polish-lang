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
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                FeatureCard(feature: Theme.readingFeature, title: "Новый текст") {
                    topicSection
                    levelSection
                    generateSection
                }
                advancedSection
                if !readings.texts.isEmpty {
                    historySection
                }
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

    private var topicSection: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 12) {
            Text("Тема")
                .font(.ui(.footnote, weight: .semibold))
                .foregroundStyle(Theme.readingFeature.accent)
            TextField("Например: wizyta u lekarza или «поиск квартиры»", text: $session.topic)
                .font(.ui(.title3, weight: .medium))
                .foregroundStyle(Color.white)
                .submitLabel(.go)
                .focused($topicFocused)
                .onSubmit(generate)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 56)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                        .strokeBorder(topicFocused ? Theme.readingFeature.accent : Color.clear, lineWidth: 2)
                }
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
        return VStack(alignment: .leading, spacing: 12) {
            Text("Уровень")
                .font(.ui(.footnote, weight: .semibold))
                .foregroundStyle(Theme.readingFeature.accent)
            SegmentedPills(items: CEFRLevel.allCases, title: { $0.rawValue }, selection: $settings.readingLevel)
            Text(settings.readingLevel.summary)
                .font(.ui(.footnote))
                .foregroundStyle(Color.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch session.phase {
            case .generating(let level):
                WorkingRow(text: "Пишу текст уровня \(level.rawValue)…") { session.stop() }
                    .padding(.vertical, 4)
            case .failed(let message, let canRetry):
                Banner(text: message, style: .error)
                if canRetry {
                    Button("Ещё раз") { session.retry() }
                        .buttonStyle(.pill(.secondary, size: .medium))
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
                    .buttonStyle(.pill(.inverse, size: .medium))
            } else if session.topic.trimmed.isEmpty {
                Text("Введи тему или выбери чип")
                    .font(.ui(.footnote))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
    }

    private func generateButton(enabled: Bool) -> some View {
        Button(action: generate) {
            Label("Сгенерировать", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pill(.primary))
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

    /// Wise-style accordion row: a bold title and a round "+" on the right.
    private var advancedSection: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 0) {
            Hairline()
            Button {
                withAnimation(.snappy(duration: 0.25)) { showAdvanced.toggle() }
            } label: {
                HStack {
                    Text("Тип текста и мои слова")
                        .font(.ui(.headline))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: showAdvanced ? "minus" : "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 48, height: 48)
                        .background(Theme.fill, in: Circle())
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showAdvanced ? "открыто" : "закрыто")
            if showAdvanced {
                VStack(alignment: .leading, spacing: 16) {
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
                        .font(.ui(.footnote))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 20)
                .transition(.opacity)
            }
            Hairline()
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "История") {
                Button("Все тексты") { session.path.append(.history) }
                    .buttonStyle(.pill(.secondary, size: .small))
            }
            .padding(.bottom, 8)
            ForEach(Array(readings.texts.prefix(3).enumerated()), id: \.element.id) { index, text in
                if index > 0 {
                    Hairline()
                }
                Button {
                    session.open(text)
                } label: {
                    HistoryRow(text: text)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HistoryRow: View {
    let text: ReadingText

    var body: some View {
        HStack(spacing: 16) {
            IconCircle(systemName: "doc.text")
            VStack(alignment: .leading, spacing: 2) {
                Text(text.title)
                    .font(.ui(.headline))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(text.topic)
                    Text("·")
                    Text(text.created, format: .dateTime.day().month().year())
                }
                .font(.ui(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            LevelBadge(level: text.level)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
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
                .listRowBackground(Theme.background)
                .listRowSeparatorTint(Theme.line)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.screen, bottom: 0, trailing: Theme.Space.screen))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        readings.delete(id: text.id)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("История")
        .overlay {
            if readings.texts.isEmpty {
                EmptyState(icon: "clock.arrow.circlepath", title: "Пока пусто", text: "Сохранённые тексты появятся здесь.")
            }
        }
    }
}
