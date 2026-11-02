import SwiftUI

/// Mistakes in the text are links with a private scheme; a tap opens `plerr://<index>`.
enum FeedbackLink {
    static let scheme = "plerr"

    static func url(for index: Int) -> URL? {
        URL(string: "\(scheme)://\(index)")
    }

    static func index(from url: URL) -> Int? {
        guard url.scheme == scheme else { return nil }
        return Int(url.absoluteString.dropFirst(scheme.count + 3))
    }
}

struct FeedbackScreen: View {
    let id: String
    @Environment(WritingStore.self) private var texts

    var body: some View {
        if let text = texts.text(id: id) {
            FeedbackView(text: text)
        } else {
            EmptyState(icon: "doc.text", title: "Текст удалён", text: "Этого разбора больше нет в истории.")
                .screenBackground()
        }
    }
}

/// The feedback (TZ 3, 4.4): the grade, the task points, the register, the text with numbered
/// mistakes, the corrected version, upgrades and words for the cards.
struct FeedbackView: View {
    let text: WritingText
    @Environment(AppModel.self) private var app
    @Environment(WritingSession.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @State private var activeError: Int?
    @State private var showCorrected = false
    @State private var showTask = false
    @State private var pickedWords: Set<Int>
    @State private var addedMessage: String?
    @State private var deleteArmed = false
    @State private var photos: [Data] = []
    @State private var photoPage: PhotoPage?

    init(text: WritingText) {
        self.text = text
        _pickedWords = State(initialValue: Set(text.result.newWords.indices))
    }

    private var result: TextCheck {
        text.result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.section) {
                    summary
                    if !result.points.isEmpty {
                        points
                    }
                    register
                    markedText
                    if !result.correctedText.isEmpty {
                        corrected
                    }
                    if !result.upgrade.isEmpty {
                        upgrades
                    }
                    if !result.newWords.isEmpty {
                        words
                    }
                    if !photos.isEmpty {
                        photoSection
                    }
                    taskSection
                    actions
                }
                .padding(.horizontal, Theme.Space.screen)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: Theme.readerWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .environment(\.openURL, OpenURLAction { url in
                if let index = FeedbackLink.index(from: url) {
                    activeError = index
                    withAnimation { proxy.scrollTo("error-\(index)", anchor: .center) }
                }
                return .handled
            })
            #if DEBUG
            .task {
                // Demo screenshots: the text with the red-pen marks and the first mistake selected.
                guard DemoMode.screen == "feedback-text" else { return }
                try? await Task.sleep(nanoseconds: 800_000_000)
                activeError = 0
                proxy.scrollTo("marked-text", anchor: .top)
            }
            #endif
        }
        .screenBackground()
        .navigationTitle("Разбор")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $photoPage) { page in
            PhotoViewer(photos: photos, index: page.index)
        }
        .task {
            if let id = text.photoId {
                photos = app.photos.photos(for: id).compactMap { try? Data(contentsOf: $0) }
            }
        }
    }

    // MARK: The grade

    private var summary: some View {
        FeatureCard(feature: Theme.writingFeature) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(text.score)%")
                    .font(.ui(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.writingFeature.accent)
                if let points = text.taskPoints, let weight = text.taskWeight {
                    Text("\(points)/\(weight)")
                        .font(.ui(.title2, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                Spacer(minLength: 8)
                Tag(text: text.passed ? "выше порога" : "ниже порога", style: text.passed ? .positive : .negative)
            }
            Text("Порог \(text.examLevel.rawValue): \(text.examLevel.threshold)% · оценка по нашей шкале, приближение к официальной")
                .font(.ui(.footnote))
                .foregroundStyle(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Criterion.allCases) { criterion in
                    let value = result.scores[criterion]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(criterion.title)
                                .font(.ui(.subheadline))
                            Spacer()
                            Text("\(value)/5")
                                .font(.ui(.subheadline, weight: .semibold))
                                .monospacedDigit()
                        }
                        ProgressBar(value: Double(value) / 5, tint: value >= 4 ? Color(hex: 0x7FD4A3) : Theme.writingFeature.accent, track: Color.white.opacity(0.16))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !result.summaryRu.isEmpty {
                Text(result.summaryRu)
                    .font(.ui(.body))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(metaLine)
                .font(.ui(.footnote))
                .foregroundStyle(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "слов: 112 · от руки · с опорой, подсмотрено идей 2/6 · 34 мин".
    private var metaLine: String {
        var parts = ["слов: \(text.wordCount)", text.hand ? "от руки" : "печатаю"]
        if text.support.opened {
            parts.append("с опорой, подсмотрено идей \(text.support.ideasRevealed)/\(text.support.ideasTotal)")
        } else {
            parts.append("без опоры")
        }
        parts.append("\(max(1, text.seconds / 60)) мин")
        return parts.joined(separator: " · ")
    }

    // MARK: Points and register

    private var points: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Пункты задания")
            ForEach(Array(result.points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: 12) {
                    Text(point.status.mark)
                        .font(.ui(.headline, weight: .bold))
                        .foregroundStyle(color(for: point.status))
                        .frame(width: 32, height: 32)
                        .background(fill(for: point.status), in: Circle())
                        .accessibilityLabel(label(for: point.status))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.punkt)
                            .font(Theme.polish(.body, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(point.quote.isEmpty ? "в тексте не нашлось" : "«\(point.quote)»")
                            .font(Theme.polish(.subheadline))
                            .italic(!point.quote.isEmpty)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func color(for status: PointStatus) -> Color {
        switch status {
        case .yes: return Theme.positive
        case .partly: return Theme.warning
        case .no: return Theme.negative
        }
    }

    private func fill(for status: PointStatus) -> Color {
        switch status {
        case .yes: return Theme.positiveFill
        case .partly: return Theme.warningFill
        case .no: return Theme.negativeFill
        }
    }

    private func label(for status: PointStatus) -> String {
        switch status {
        case .yes: return "раскрыт"
        case .partly: return "раскрыт частично"
        case .no: return "не раскрыт"
        }
    }

    private var register: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Регистр и форма")
            HStack(spacing: 8) {
                Tag(text: result.register.consistent ? "единый" : "смешан", style: result.register.consistent ? .positive : .negative)
                if !result.register.expected.isEmpty {
                    Text("нужен: \(result.register.expected)" + (result.register.detected.isEmpty ? "" : " · в тексте: \(result.register.detected)"))
                        .font(.ui(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            ForEach(Array(result.register.issuesRu.enumerated()), id: \.offset) { _, issue in
                Banner(text: issue, style: .warning)
            }
        }
    }

    // MARK: The text

    private var markedText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .frame(height: 0)
                .id("marked-text")
            SectionHeader(title: "Твой текст") {
                Text(result.errors.isEmpty ? "ошибок не найдено" : "нажми на подчёркнутое")
                    .font(.ui(.footnote))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(attributedText)
                .font(Theme.readerFont)
                .lineSpacing(8)
                .tint(Theme.mistakeInk)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.notebookPaper, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous).strokeBorder(Theme.line)
                }
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(result.errors.enumerated()), id: \.offset) { index, error in
                        if index > 0 {
                            Hairline()
                        }
                        errorRow(index, error)
                            .id("error-\(index)")
                    }
                }
            }
        }
    }

    private var ranges: [Int: Range<String.Index>] {
        WritingRules.errorRanges(in: text.text, errors: result.errors)
    }

    /// Plain text pieces with attributes; nothing from the model is interpreted as markup.
    private var attributedText: AttributedString {
        let source = text.text
        var output = AttributedString()
        var cursor = source.startIndex
        for (index, range) in ranges.sorted(by: { $0.value.lowerBound < $1.value.lowerBound }) {
            if cursor < range.lowerBound {
                output.append(AttributedString(String(source[cursor..<range.lowerBound])))
            }
            var piece = AttributedString(String(source[range]))
            let underline: Text.LineStyle = Text.LineStyle(pattern: .solid, color: Theme.mistakeInk)
            piece.underlineStyle = underline
            if activeError == index {
                let highlight: Color = Theme.negativeFill
                piece.backgroundColor = highlight
            }
            piece.link = FeedbackLink.url(for: index)
            output.append(piece)
            var number = AttributedString(Self.superscript(index + 1))
            number.link = FeedbackLink.url(for: index)
            output.append(number)
            cursor = range.upperBound
        }
        if cursor < source.endIndex {
            output.append(AttributedString(String(source[cursor...])))
        }
        return output
    }

    static func superscript(_ number: Int) -> String {
        let digits: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
        return String(String(number).map { digits[$0] ?? $0 })
    }

    private func errorRow(_ index: Int, _ error: TextError) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.ui(.footnote, weight: .bold))
                .foregroundStyle(activeError == index ? Color.white : Theme.mistakeInk)
                .frame(width: 28, height: 28)
                .background(activeError == index ? Theme.mistakeInk : Theme.negativeFill, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(error.fragment)
                        .strikethrough(true, color: Theme.mistakeInk)
                        .foregroundStyle(Theme.mistakeInk)
                    Text("→")
                        .foregroundStyle(Theme.textTertiary)
                    Text(error.correction.isEmpty ? "убрать" : error.correction)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.fixInk)
                }
                .font(Theme.polish(.body))
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if !error.type.isEmpty {
                        Tag(text: error.type, style: .neutral)
                    }
                    if ranges[index] == nil {
                        Tag(text: "не найдено в тексте", style: .warning)
                    }
                }
                if !error.ruleRu.isEmpty {
                    Text(error.ruleRu)
                        .font(.ui(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(activeError == index ? Theme.negativeFill.opacity(0.5) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { activeError = index }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ошибка \(index + 1): \(error.fragment) → \(error.correction). \(error.ruleRu)")
    }

    // MARK: Fixes and words

    private var corrected: some View {
        Accordion(title: "Исправленная версия", isOpen: $showCorrected) {
            Text(result.correctedText)
                .font(Theme.readerFont)
                .lineSpacing(8)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var upgrades: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Как сказать на уровень выше")
            ForEach(Array(result.upgrade.enumerated()), id: \.offset) { _, upgrade in
                VStack(alignment: .leading, spacing: 4) {
                    if !upgrade.plain.isEmpty {
                        Text(upgrade.plain)
                            .font(Theme.polish(.body))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("→ " + upgrade.better)
                        .font(Theme.polish(.body, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    if !upgrade.ru.isEmpty {
                        Text(upgrade.ru)
                            .font(.ui(.footnote))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .cardBackground(padding: 16, radius: Theme.Radius.tile)
            }
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Слова для повторения")
            ForEach(Array(result.newWords.enumerated()), id: \.offset) { index, word in
                CheckRow(title: "\(word.pl) — \(word.ru)", isOn: Binding(
                    get: { pickedWords.contains(index) },
                    set: { isOn in
                        if isOn { pickedWords.insert(index) } else { pickedWords.remove(index) }
                    }
                ))
            }
            Button {
                let picked = pickedWords.sorted().compactMap { result.newWords.indices.contains($0) ? result.newWords[$0] : nil }
                let saved = session.addToCards(picked)
                addedMessage = saved.cards.isEmpty ? "Эти слова уже в карточках" : "Добавлено в карточки: \(saved.cards.count)"
                toasts.show(addedMessage ?? "")
            } label: {
                Label(addedMessage ?? "Добавить в карточки", systemImage: addedMessage == nil ? "plus.rectangle.on.rectangle" : "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.secondary))
            .disabled(pickedWords.isEmpty || addedMessage != nil)
            Text("Слово сохранится в той форме, как его нужно употребить в тексте, с начальной формой и переводом.")
                .font(.ui(.footnote))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Фото листа")
            PhotoStrip(photos: photos) { photoPage = PhotoPage(index: $0) }
        }
    }

    private var taskSection: some View {
        Accordion(title: "Задание", isOpen: $showTask) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text.task.polecenie)
                    .font(Theme.polish(.body, weight: .medium))
                ForEach(Array(text.task.punkty.enumerated()), id: \.offset) { _, point in
                    Text("• " + point)
                        .font(Theme.polish(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }
                if !text.ideasDraft.isEmpty {
                    Text("Pomysły: " + text.ideasDraft)
                        .font(.ui(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 6)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                session.path = []
            } label: {
                Label("К заданиям", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.primary))
            Button {
                if deleteArmed {
                    session.path.removeAll { $0 == .feedback(text.id) }
                    app.deleteWritingText(id: text.id)
                } else {
                    deleteArmed = true
                }
            } label: {
                Text(deleteArmed ? "Текст удалится. Точно?" : "Удалить текст")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.destructive, size: .medium))
        }
    }
}

/// A Wise-style accordion: a bold title and a round "+" on the right.
struct Accordion<Content: View>: View {
    let title: String
    @Binding var isOpen: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            Button {
                withAnimation(.snappy(duration: 0.25)) { isOpen.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.ui(.headline))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: isOpen ? "minus" : "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(Theme.fill, in: Circle())
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isOpen ? "открыто" : "закрыто")
            if isOpen {
                content
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
            Hairline()
        }
    }
}
