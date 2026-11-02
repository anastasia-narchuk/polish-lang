import PhotosUI
import SwiftUI

/// Own words into cards: one word, a list, or photos (TZ 1, section 2).
struct AddWordsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case single, list, photo

        var id: String { rawValue }

        var title: String {
            switch self {
            case .single: return "Слово"
            case .list: return "Списком"
            case .photo: return "С фото"
            }
        }
    }

    private enum Field: Hashable {
        case pl, base, ru, list
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(CardStore.self) private var cards
    @Environment(AppSettings.self) private var settings
    @Environment(AIService.self) private var ai
    @Environment(ToastCenter.self) private var toasts

    @State private var mode: Mode = .single
    @State private var pl = ""
    @State private var base = ""
    @State private var ru = ""
    @State private var listText = ""
    @State private var review: DraftReviewModel?
    @State private var photoImport = PhotoImportModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showScanner = false
    @FocusState private var focus: Field?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SegmentedPills(items: Mode.allCases, title: { $0.title }, selection: $mode)

                    switch mode {
                    case .single: singleSections
                    case .list: listSections
                    case .photo: photoSections
                    }

                    if mode != .photo {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Определять начальную форму", isOn: $settings.wantBaseForms)
                                .font(.ui(.headline))
                            Text("AI добавит начальную форму, грамматическую пометку и чередование даже к словам с готовым переводом. Если выключить, такие слова сохраняются сразу.")
                                .font(.ui(.footnote))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .cardBackground(padding: 20)
                    }

                    if !ai.hasKey {
                        Banner(text: "AI не подключён: перевод можно вписать вручную. API-ключ добавляется в настройках.", style: .info)
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
            .navigationTitle("Новые слова")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    if focus != nil && focus != .ru {
                        PolishLettersBar(compact: true, insert: insert)
                    }
                }
            }
            .navigationDestination(item: $review) { model in
                DraftReviewView(model: model) { saved in
                    review = nil
                    if saved { clearInput() }
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
        }
        .toastOverlay()
    }

    // MARK: One word (section 2.1)

    @ViewBuilder
    private var singleSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("В той форме, как встретилось: rzece, poszłam, przy rzece")
                .font(.ui(.footnote, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("По-польски", text: $pl)
                .font(.ui(.title3, weight: .medium))
                .focused($focus, equals: .pl)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focus = .base }
                .fieldBackground(isFocused: focus == .pl)
            TextField("Начальная форма (необязательно)", text: $base)
                .focused($focus, equals: .base)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focus = .ru }
                .fieldBackground(isFocused: focus == .base)
            TextField("Перевод (необязательно)", text: $ru)
                .focused($focus, equals: .ru)
                .submitLabel(.done)
                .onSubmit(addSingle)
                .fieldBackground(isFocused: focus == .ru)
            Text("Без перевода AI подберёт его сам — так, чтобы по нему вспоминалась именно эта форма.")
                .font(.ui(.footnote))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: addSingle) {
                Label("Добавить", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.primary))
            .disabled(pl.trimmed.isEmpty)
            .padding(.top, 4)
        }
    }

    private func addSingle() {
        let entry = ParsedEntry(pl: PolishText.nfc(pl.collapsingWhitespace), base: PolishText.nfc(base.collapsingWhitespace), ru: ru.trimmed)
        guard !entry.pl.isEmpty else { return }
        let prepared = DraftBuilder.prepare([CardDraft(entry: entry, source: .manual)], existingKeys: cards.dedupKeys)
        guard !prepared.drafts.isEmpty else {
            toasts.show("Эта форма уже есть в карточках")
            return
        }
        proceed(with: prepared, source: .manual)
    }

    // MARK: A list (section 2.2)

    @ViewBuilder
    private var listSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Список")
                .font(.ui(.footnote, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            ZStack(alignment: .topLeading) {
                if listText.isEmpty {
                    Text(verbatim: "rzece\nrzece — реке\nrzece [rzeka] — реке\nmorzu, przy rzece, poszłam")
                        .font(.ui(.body))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $listText)
                    .font(.ui(.body))
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .list)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: 180)
            }
            .fieldBackground(isFocused: focus == .list)
            Text("Строка — слово или фраза. Перевод — через тире с пробелами или Tab, начальная форма — в [квадратных скобках]. Одна строка без тире делится по запятым.")
                .font(.ui(.footnote))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: addList) {
                Label("Разобрать и добавить", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.primary))
            .disabled(listText.trimmed.isEmpty)
            .padding(.top, 4)
        }
    }

    private func addList() {
        let entries = OwnListParser.parse(listText)
        guard !entries.isEmpty else {
            toasts.show("Не нашла слов в списке")
            return
        }
        let prepared = DraftBuilder.prepare(entries.map { CardDraft(entry: $0, source: .list) }, existingKeys: cards.dedupKeys)
        guard !prepared.drafts.isEmpty else {
            toasts.show("Эти слова уже есть в тетради")
            return
        }
        proceed(with: prepared, source: .list)
    }

    /// Saves right away when nothing needs AI; otherwise opens the check screen.
    private func proceed(with prepared: DraftPreparation, source: CardSource) {
        let wantBase = settings.wantBaseForms
        focus = nil
        if prepared.drafts.allSatisfy({ !$0.needsAI(wantBase: wantBase) }) {
            let result = DraftBuilder.save(prepared.drafts, existingKeys: cards.dedupKeys, photoId: nil)
            cards.add(result.cards)
            var message = result.message
            if prepared.duplicates > 0 { message += ". Пропущено повторов: \(prepared.duplicates)" }
            toasts.show(message)
            clearInput()
        } else {
            review = DraftReviewModel(drafts: prepared.drafts, duplicates: prepared.duplicates, source: source, wantBase: wantBase)
        }
    }

    // MARK: Photos (section 2.3)

    @ViewBuilder
    private var photoSections: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 16) {
            Text("Фото тетради, учебника или доски")
                .font(.ui(.footnote, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            SegmentedPills(items: PhotoMode.allCases, title: { $0.title }, selection: $settings.photoMode)
            if !photoImport.photos.isEmpty {
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
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, PolishAI.maxPhotos - photoImport.photos.count),
                    matching: .images
                ) {
                    Label("Из галереи", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.pill(.secondary, size: .medium))
            }
            .disabled(!photoImport.canAddMore || photoImport.isRecognizing)
            if photoImport.isPreparing {
                WorkingRow(text: "Готовлю фото…")
            }
            Text("До \(PolishAI.maxPhotos) фото за раз. «Только выделенное» — подчёркнутые, обведённые, выделенные маркером слова и слова на полях.")
                .font(.ui(.footnote))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if photoImport.isRecognizing {
                WorkingRow(text: "Распознаю слова…") { photoImport.stop() }
            } else {
                Button {
                    photoImport.recognize(mode: settings.photoMode, ai: ai, existingKeys: cards.dedupKeys) { model in
                        review = model
                    }
                } label: {
                    Label("Распознать", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.primary))
                .disabled(photoImport.photos.isEmpty || !ai.hasKey)
            }
            if let message = photoImport.message {
                Banner(text: message, style: .warning)
            }
        }
    }

    private var photoThumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photoImport.photos.indices, id: \.self) { index in
                    if let image = UIImage(data: photoImport.photos[index]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    photoImport.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(Color.white, Color.black.opacity(0.6))
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                                .accessibilityLabel("Убрать фото \(index + 1)")
                            }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickerItems = []
        photoImport.isPreparing = true
        Task { @MainActor in
            var prepared: [Data] = []
            var failure: String?
            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        failure = ImagePreparation.Failure.unreadable.message
                        continue
                    }
                    prepared.append(try await Self.jpeg(from: data))
                } catch let error as ImagePreparation.Failure {
                    failure = error.message
                } catch {
                    failure = ImagePreparation.Failure.unreadable.message
                }
            }
            photoImport.add(prepared)
            if let failure { photoImport.message = failure }
            photoImport.isPreparing = false
        }
    }

    private func prepare(images: [UIImage]) {
        guard !images.isEmpty else { return }
        photoImport.isPreparing = true
        Task { @MainActor in
            var prepared: [Data] = []
            for image in images.prefix(PolishAI.maxPhotos) {
                if let data = try? ImagePreparation.jpeg(from: image) {
                    prepared.append(data)
                }
            }
            if images.count > PolishAI.maxPhotos {
                photoImport.message = "Отсканировано \(images.count) страниц — взяла первые \(PolishAI.maxPhotos)."
            }
            photoImport.add(prepared)
            photoImport.isPreparing = false
        }
    }

    /// Decoding and resizing happen off the main thread.
    private static func jpeg(from data: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try ImagePreparation.jpeg(fromData: data)
        }.value
    }

    // MARK: Helpers

    private func insert(_ letter: String) {
        switch focus {
        case .pl: pl += letter
        case .base: base += letter
        case .list: listText += letter
        case .ru, .none: break
        }
    }

    private func clearInput() {
        pl = ""
        base = ""
        ru = ""
        listText = ""
        photoImport.reset()
    }
}
