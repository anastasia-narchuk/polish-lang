import PhotosUI
import SwiftUI

/// Shows the open workspace of the session; a new task gets a fresh view state.
struct WorkspaceScreen: View {
    @Environment(WritingSession.self) private var session

    var body: some View {
        if let model = session.workspace {
            WorkspaceView(model: model)
                .id(model.id)
        } else if session.isGenerating {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.ink)
                Text("Готовлю задание…")
                    .heading(.title3)
                Button("Стоп") { session.stop() }
                    .buttonStyle(.pill(.secondary, size: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
        } else {
            EmptyState(icon: "square.and.pencil", title: "Задание не выбрано", text: "Начни с задания на сегодня или выбери форму.")
                .screenBackground()
        }
    }
}

/// The workspace (TZ 3, 4.2): the task, the support, the field or the photos, the self-check
/// list and the check. On iPad the support is a column on the right with its own scroll.
struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    @Environment(WritingSession.self) private var session
    @Environment(AIService.self) private var ai
    @Environment(AppSettings.self) private var settings
    @Environment(TextErrorStore.self) private var textErrors
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showScanner = false
    @State private var isPreparing = false
    @State private var photoMessage: String?
    @State private var photoPage: PhotoPage?
    @State private var regenerateArmed = false
    @State private var showIdeasDraft = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    taskBlock
                    if !showsSideColumn {
                        SupportPanel(model: model, traps: textErrors.traps())
                            .cardBackground(padding: 20)
                    }
                    SegmentedPills(items: [false, true], title: { $0 ? "От руки · фото" : "Печатаю" }, selection: $model.hand)
                        .disabled(model.isWorking)
                    if model.hand {
                        handPane
                    } else {
                        typedPane
                    }
                    checklist
                    actions
                }
                .padding(.horizontal, Theme.Space.screen)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: Theme.readerWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            if showsSideColumn {
                Rectangle()
                    .fill(Theme.line)
                    .frame(width: 1)
                    .ignoresSafeArea()
                ScrollView {
                    SupportPanel(model: model, traps: textErrors.traps())
                        .padding(20)
                }
                .frame(width: 340)
                .background(Theme.surface.ignoresSafeArea())
            }
        }
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.policy.timer == .stopwatch {
                    StopwatchLabel(started: model.started)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            loadPicked(items)
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { images in
                showScanner = false
                prepare(images: images)
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .sheet(item: $photoPage) { page in
            PhotoViewer(photos: model.photos, index: page.index)
        }
        .onDisappear {
            if model.result == nil { model.saveDraftNow() }
        }
        #if DEBUG
        .task {
            if let text = DemoMode.workspaceText, model.text.isEmpty {
                model.text = text
                model.revealIdea(0)
            }
        }
        #endif
    }

    private var showsSideColumn: Bool {
        sizeClass == .regular
    }

    private var title: String {
        switch model.mode {
        case .akapit: return "Akapit"
        case .exam: return "Egzamin \(model.task.level.rawValue)"
        case .own: return "Свой текст"
        }
    }

    // MARK: The task

    private var taskBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                Tag(text: badge, style: .accent)
                if !model.task.register.isEmpty {
                    Tag(text: model.task.register, style: .neutral)
                }
            }
            Text(model.task.polecenie)
                .font(Theme.polish(.title3, weight: .semibold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            if !model.task.punkty.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(model.task.punkty.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                            Text(point)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(Theme.polish(.body))
                        .foregroundStyle(Theme.text)
                    }
                }
            }
            if model.policy.translationAvailable && !model.task.ru.isEmpty {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { model.translationShown.toggle() }
                } label: {
                    Label("Перевод задания", systemImage: model.translationShown ? "chevron.down" : "chevron.right")
                        .font(.ui(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
                if model.translationShown {
                    Text(model.task.ru)
                        .font(.ui(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !model.task.must.isEmpty {
                chips("Обязательные слова", model.task.must)
            }
            if !model.task.mustConnectors.isEmpty {
                chips("Связки", model.task.mustConnectors)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Объём: \(model.range.lowerBound)–\(model.range.upperBound) слов")
                    .font(.ui(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                if model.mode != .own {
                    Button(regenerateArmed ? "Текст удалится. Точно?" : "Другая тема") {
                        if model.currentText.trimmed.isEmpty || regenerateArmed {
                            regenerateArmed = false
                            session.anotherTask()
                        } else {
                            regenerateArmed = true
                        }
                    }
                    .buttonStyle(.pill(regenerateArmed ? .destructive : .tertiary, size: .small))
                    .disabled(model.isWorking || session.isGenerating || !ai.hasKey)
                }
            }
        }
        .cardBackground(padding: 20)
    }

    private var badge: String {
        let form = model.task.kind?.title ?? model.task.form
        return form.isEmpty ? model.task.level.rawValue : "\(model.task.level.rawValue) · \(form)"
    }

    /// Required words turn green once they are used in any form.
    private func chips(_ title: String, _ words: [String]) -> some View {
        let used = model.usedChips
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.ui(.footnote, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(words, id: \.self) { word in
                    let isUsed = used.contains(word)
                    HStack(spacing: 4) {
                        if isUsed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(word)
                    }
                    .font(Theme.polish(.subheadline, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(isUsed ? Theme.positiveFill : Theme.fill, in: Capsule())
                    .foregroundStyle(isUsed ? Theme.positive : Theme.text)
                    .accessibilityLabel(word + (isUsed ? ", использовано" : ""))
                }
            }
        }
    }

    // MARK: Typing

    private var typedPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            ideasDraftRow
            NotebookField(
                text: $model.text,
                lettersBar: model.lettersBarShown,
                isEditable: !model.isWorking,
                demoInsertion: demoInsertion
            )
            HStack {
                WordCounter(count: model.wordCount, range: model.range, status: model.lengthStatus)
                Spacer()
            }
        }
    }

    private var demoInsertion: (letter: String, offset: Int)? {
        #if DEBUG
        return DemoMode.workspaceInsertion
        #else
        return nil
        #endif
    }

    /// "Pomysły": a minute of ideas in Russian, not checked (TZ 3, section 6).
    private var ideasDraftRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { showIdeasDraft.toggle() }
            } label: {
                Label("Pomysły: идеи по-русски (необязательно)", systemImage: showIdeasDraft ? "chevron.down" : "chevron.right")
                    .font(.ui(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            if showIdeasDraft {
                TextField("1–2 минуты: о чём напишешь", text: $model.ideasDraft, axis: .vertical)
                    .lineLimit(2...6)
                    .fieldBackground()
            }
        }
    }

    // MARK: By hand

    @ViewBuilder
    private var handPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !model.hasTranscript {
                Banner(text: "Пиши на бумаге, без телефона и словаря. Потом сфотографируй лист целиком при хорошем свете, один лист в кадре: до \(PolishAI.maxPhotos) фото.", style: .info)
            }
            if !model.photos.isEmpty {
                photoThumbnails
            }
            HStack(spacing: 8) {
                if DocumentScanner.isSupported {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Сканировать", systemImage: "doc.viewfinder")
                    }
                    .buttonStyle(.pill(.secondary, size: .medium))
                }
                PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, PolishAI.maxPhotos - model.photos.count), matching: .images) {
                    Label("Из галереи", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.pill(.secondary, size: .medium))
            }
            .disabled(model.photos.count >= PolishAI.maxPhotos || model.isWorking)
            if isPreparing {
                WorkingRow(text: "Готовлю фото…")
            }
            if let photoMessage {
                Banner(text: photoMessage, style: .warning)
            }
            if model.hasTranscript {
                transcriptReview
            }
        }
    }

    private var photoThumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(model.photos.indices, id: \.self) { index in
                    VStack(spacing: 6) {
                        if let image = UIImage(data: model.photos[index]) {
                            Button {
                                photoPage = PhotoPage(index: index)
                            } label: {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 128)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Фото \(index + 1), открыть")
                        }
                        HStack(spacing: 4) {
                            photoButton("arrow.left", label: "Раньше") { model.movePhoto(from: index, by: -1) }
                                .disabled(index == 0)
                            photoButton("rotate.right", label: "Повернуть") { rotate(index) }
                            photoButton("arrow.right", label: "Позже") { model.movePhoto(from: index, by: 1) }
                                .disabled(index == model.photos.count - 1)
                            photoButton("xmark", label: "Убрать фото") { model.removePhoto(at: index) }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(model.isWorking)
    }

    private func photoButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(CircleIconButtonStyle(size: 28))
        .accessibilityLabel(label)
    }

    private var transcriptReview: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Проверь расшифровку")
            Text("Исправь только то, что прочитано НЕ так, как написано у тебя. Свои ошибки не трогай — их найдёт разбор.")
                .font(.ui(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.unreadableShare > 0.15 {
                Banner(text: "Много нечитаемых слов [?]. Сфотографируй ближе, при дневном свете, и распознай ещё раз.", style: .warning)
            }
            NotebookField(text: $model.transcript, lettersBar: settings.writing.lettersBar, isEditable: !model.isWorking, minLines: 6)
            WordCounter(count: model.wordCount, range: model.range, status: model.lengthStatus)
        }
    }

    // MARK: Self-check and the check

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Перед отправкой")
                .heading(.headline)
                .foregroundStyle(Theme.text)
                .padding(.bottom, 4)
            CheckRow(title: "Все пункты задания раскрыты", isOn: $model.checklist.points)
            CheckRow(title: "Объём в норме", isOn: $model.checklist.length)
            CheckRow(title: model.task.isFormal ? "Везде Pan/Pani, без «ty»" : "Регистр единый: «ty» или Pan/Pani", isOn: $model.checklist.register)
            if isLetterTask {
                CheckRow(title: "Есть формулы начала и конца письма", isOn: $model.checklist.formulas)
            }
            CheckRow(title: "Ogonki проверены: ą ę ó ś ź ż ć ń ł", isOn: $model.checklist.ogonki)
        }
        .cardBackground(padding: 20)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.phase {
            case .transcribing:
                WorkingRow(text: "Читаю рукопись…") { model.stop() }
            case .checking:
                WorkingRow(text: "Проверяю как экзаменатор… (до минуты)") { model.stop() }
            case .failed(let message, let canRetry):
                Banner(text: message, style: .error)
                if canRetry {
                    Button("Ещё раз") { model.retry() }
                        .buttonStyle(.pill(.secondary, size: .medium))
                }
                checkButton
            case .writing, .reviewingTranscript:
                checkButton
            }
            if !ai.hasKey {
                Banner(text: "Проверка недоступна: добавь API-ключ Claude или Gemini в настройках. Писать и сохранять черновик можно.", style: .info)
            } else if !model.hand && model.wordCount < WritingRules.minimumWords {
                Text("Напиши хотя бы пару предложений — от \(WritingRules.minimumWords) слов.")
                    .font(.ui(.footnote))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    /// Letters and e-mails need opening and closing formulas.
    private var isLetterTask: Bool {
        if let kind = model.task.kind { return kind.isLetter }
        let form = model.task.form.lowercased()
        return form.contains("list") || form.contains("mail") || form.contains("wiadomo")
    }

    private var checkButton: some View {
        Button {
            model.check()
        } label: {
            Label(checkTitle, systemImage: model.hand && !model.hasTranscript ? "text.viewfinder" : "checkmark.seal")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pill(.primary))
        .disabled(!model.canCheck || !ai.hasKey)
    }

    private var checkTitle: String {
        if model.hand {
            return model.hasTranscript ? "Всё верно, разобрать с коучем" : "Распознать рукопись"
        }
        return "Разобрать с коучем"
    }

    // MARK: Photos

    private func rotate(_ index: Int) {
        guard model.photos.indices.contains(index) else { return }
        let data = model.photos[index]
        Task { @MainActor in
            if let rotated = try? await Task.detached(priority: .userInitiated, operation: { try ImagePreparation.rotatedClockwise(data) }).value {
                model.replacePhoto(at: index, with: rotated)
            }
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickerItems = []
        isPreparing = true
        photoMessage = nil
        Task { @MainActor in
            var prepared: [Data] = []
            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        photoMessage = ImagePreparation.Failure.unreadable.message
                        continue
                    }
                    prepared.append(try await Task.detached(priority: .userInitiated) { try ImagePreparation.jpeg(fromData: data) }.value)
                } catch let error as ImagePreparation.Failure {
                    photoMessage = error.message
                } catch {
                    photoMessage = ImagePreparation.Failure.unreadable.message
                }
            }
            model.addPhotos(prepared)
            isPreparing = false
        }
    }

    private func prepare(images: [UIImage]) {
        guard !images.isEmpty else { return }
        isPreparing = true
        Task { @MainActor in
            let prepared = images.prefix(PolishAI.maxPhotos).compactMap { try? ImagePreparation.jpeg(from: $0) }
            if images.count > PolishAI.maxPhotos {
                photoMessage = "Отсканировано \(images.count) страниц — взяла первые \(PolishAI.maxPhotos)."
            }
            model.addPhotos(prepared)
            isPreparing = false
        }
    }
}

/// "87 слов · цель 100–120": green in range, yellow up to 20% off, red beyond.
struct WordCounter: View {
    let count: Int
    let range: ClosedRange<Int>
    let status: LengthStatus

    var body: some View {
        Text("\(Russian.words(count)) · цель \(range.lowerBound)–\(range.upperBound)")
            .font(.ui(.footnote, weight: .semibold))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(fill, in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .ok: return Theme.positive
        case .near: return Theme.warning
        case .far: return Theme.negative
        }
    }

    private var fill: Color {
        switch status {
        case .ok: return Theme.positiveFill
        case .near: return Theme.warningFill
        case .far: return Theme.negativeFill
        }
    }
}

/// A manual tick of the self-check list: it is saved with the text and never blocks the check.
struct CheckRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? Theme.positive : Theme.textTertiary)
                Text(title)
                    .font(.ui(.body))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The stopwatch of the exam training.
struct StopwatchLabel: View {
    let started: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = max(0, Int(context.date.timeIntervalSince(started)))
            Label(String(format: "%02d:%02d", seconds / 60, seconds % 60), systemImage: "stopwatch")
                .labelStyle(.titleAndIcon)
                .font(.ui(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .accessibilityLabel("Прошло \(seconds / 60) мин \(seconds % 60) с")
        }
    }
}
