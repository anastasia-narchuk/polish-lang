import SwiftUI

/// Shows the current text of the session; a new text gets a fresh reader state.
struct ReaderScreen: View {
    @Environment(ReadingSession.self) private var session

    var body: some View {
        if let text = session.current {
            ReaderView(text: text)
                .id(text.id)
        } else {
            ContentUnavailableView(
                "Текст не выбран",
                systemImage: "doc.text",
                description: Text("Сгенерируй текст или открой его из истории.")
            )
        }
    }
}

/// The reader (TZ 2, section 5). Every word is a link inside one `Text`, so the text flows
/// and wraps naturally; model output is only ever used as plain strings.
struct ReaderView: View {
    @Environment(ReadingSession.self) private var session
    @Environment(AIService.self) private var ai
    @Environment(CardStore.self) private var cards
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: ReaderModel

    init(text: ReadingText) {
        _model = State(initialValue: ReaderModel(text: text))
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statusBanners
                    paragraphs
                    legend
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: Theme.readerWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if showsSidePanel {
                Divider()
                TranslationPanel(model: model)
                    .frame(width: 360)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.default, value: showsSidePanel)
        .environment(\.openURL, OpenURLAction { url in
            if let tokenID = ReaderLink.tokenID(from: url) {
                handleTap(tokenID)
            }
            return .handled
        })
        .navigationTitle(model.text.topic)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.phraseMode.toggle()
                } label: {
                    Label("Фраза", systemImage: model.phraseMode ? "text.badge.checkmark" : "text.badge.plus")
                }
                .accessibilityHint("Выделить фразу: нажать на первое и на последнее слово")
            }
        }
        .safeAreaInset(edge: .bottom) {
            phraseBar
        }
        .overlay {
            if session.isGenerating {
                generatingOverlay
            }
        }
        .sheet(isPresented: sheetPresented) {
            TranslationPanel(model: model)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
        }
        .onChange(of: model.panelPresented) { _, presented in
            if !presented { model.panelClosed() }
        }
        .onChange(of: cards.revision, initial: true) { _, _ in
            model.updateKnownWords(cards.highlightPhrases)
        }
        #if DEBUG
        .task {
            // Demo screenshots: open the panel for a word without a real tap.
            guard let word = DemoMode.autoTapWord,
                  let token = model.document.paragraphs.flatMap(\.tokens).first(where: { $0.text == word })
            else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            handleTap(token.id)
        }
        #endif
    }

    /// The panel is a column on the right on wide screens (iPad) and a bottom sheet on iPhone;
    /// with the sheet at half height the text stays tappable.
    private var showsSidePanel: Bool {
        sizeClass == .regular && model.panelPresented
    }

    private var sheetPresented: Binding<Bool> {
        Binding(
            get: { sizeClass != .regular && model.panelPresented },
            set: { model.panelPresented = $0 }
        )
    }

    private func handleTap(_ tokenID: Int) {
        if let selection = model.tap(tokenID: tokenID) {
            model.translate(selection, ai: ai, session: session)
        }
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.text.title)
                .font(Theme.polish(.title, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                LevelBadge(level: model.text.level)
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var meta: String {
        var parts = [Russian.words(model.text.wordCount), "≈ \(model.text.readingMinutes) мин", model.text.kind.title.lowercased()]
        if !model.text.usedMyWords.isEmpty {
            parts.append("моих слов: \(model.text.usedMyWords.count)")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var statusBanners: some View {
        if session.current?.id == model.text.id, let warning = session.warning {
            Banner(text: warning, style: .warning)
        }
        if case .failed(let message, let canRetry) = session.phase {
            VStack(alignment: .leading, spacing: 8) {
                Banner(text: message, style: .error)
                HStack {
                    if canRetry {
                        Button("Ещё раз") { session.retry() }
                            .buttonStyle(.bordered)
                    }
                    Button("Скрыть") { session.clearFailure() }
                }
            }
        }
        if case .cooldown(let until) = session.phase {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let wait = max(0, Int(until.timeIntervalSince(context.date).rounded(.up)))
                if wait > 0 {
                    Banner(text: "Подожди минуту: новый текст можно будет создать через \(wait) с.", style: .warning)
                }
            }
        }
    }

    private var paragraphs: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(model.document.paragraphs) { paragraph in
                Text(attributed(paragraph))
                    .font(Theme.readerFont)
                    .lineSpacing(Theme.readerLineSpacing)
                    .tint(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Plain text pieces with attributes; nothing from the model is interpreted as markup.
    private func attributed(_ paragraph: ReaderParagraph) -> AttributedString {
        var result = AttributedString()
        let selected = model.highlightedTokens
        for token in paragraph.tokens {
            var piece = AttributedString(token.text)
            if token.isWord, let url = ReaderLink.url(for: token.id) {
                piece.link = url
            }
            // Typed values pick the SwiftUI attributes (not the UIKit ones with the same names).
            let selectionColor: Color = Theme.selection
            let knownColor: Color = Theme.knownWord
            if let selected, selected.contains(token.id) {
                piece.backgroundColor = selectionColor
            } else if model.knownTokens.contains(token.id) || model.myWordTokens.contains(token.id) {
                piece.backgroundColor = knownColor
            }
            if model.keywordTokens.contains(token.id) {
                let underline: Text.LineStyle = Text.LineStyle(pattern: .dot, color: Theme.keywordLine)
                piece.underlineStyle = underline
            }
            result.append(piece)
        }
        return result
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Нажми на слово — появится перевод в контексте. Для фразы включи «Фраза» и нажми на первое и последнее слово.")
            if !model.keywordTokens.isEmpty || !model.knownTokens.isEmpty || !model.myWordTokens.isEmpty {
                Text("Пунктиром подчёркнуты ключевые слова, жёлтым отмечены слова из твоих карточек.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    session.regenerate(level: model.text.level.easier)
                } label: {
                    Label("Проще", systemImage: "arrow.down").frame(maxWidth: .infinity)
                }
                .disabled(model.text.level.easier == nil || !canRegenerate)
                Button {
                    session.regenerate(level: model.text.level.harder)
                } label: {
                    Label("Сложнее", systemImage: "arrow.up").frame(maxWidth: .infinity)
                }
                .disabled(model.text.level.harder == nil || !canRegenerate)
            }
            HStack(spacing: 10) {
                Button {
                    session.regenerate()
                } label: {
                    Label("Другой текст", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                }
                .disabled(!canRegenerate)
                Button {
                    session.saveCurrent()
                } label: {
                    Label(session.isCurrentSaved ? "В истории" : "Сохранить в историю",
                          systemImage: session.isCurrentSaved ? "checkmark" : "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .disabled(session.isCurrentSaved || session.current?.id != model.text.id)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    /// The same topic again, or at a neighbouring level; needs AI and no running generation.
    private var canRegenerate: Bool {
        ai.hasKey && !session.isGenerating
    }

    @ViewBuilder
    private var phraseBar: some View {
        if model.phraseMode {
            HStack(spacing: 12) {
                if let phrase = model.pendingPhrase {
                    Button {
                        model.translate(phrase, ai: ai, session: session)
                    } label: {
                        Label("Перевести фразу", systemImage: "character.book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        model.cancelPhrase()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Сбросить фразу")
                } else {
                    Text(model.phraseAnchor == nil ? "Нажми на первое слово фразы" : "Теперь — на последнее слово")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var generatingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Пишу новый текст…")
                    .font(.headline)
                Button("Стоп", role: .cancel) { session.stop() }
                    .buttonStyle(.bordered)
            }
        }
        .transition(.opacity)
    }
}
