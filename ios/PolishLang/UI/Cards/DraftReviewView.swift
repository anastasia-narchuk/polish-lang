import SwiftUI

/// The check screen before saving (TZ 1, section 3): the form stays as written, the rest can be edited.
struct DraftReviewView: View {
    @Bindable var model: DraftReviewModel
    /// Called with true after saving, false after "Отмена".
    var onFinish: (Bool) -> Void

    @Environment(AppModel.self) private var app
    @Environment(AIService.self) private var ai
    @Environment(CardStore.self) private var cards
    @Environment(ToastCenter.self) private var toasts
    @State private var openedPhoto: PhotoPage?

    var body: some View {
        List {
            if !model.photos.isEmpty {
                Section {
                    PhotoStrip(photos: model.photos) { index in
                        openedPhoto = PhotoPage(index: index)
                    }
                } footer: {
                    Text("Сверь слова с фото: нажми на снимок, чтобы увеличить.")
                }
            }
            statusSection
            Section {
                ForEach($model.drafts) { $draft in
                    DraftRow(draft: $draft, isWaiting: model.isWorking && !draft.answered && draft.needsAI(wantBase: model.wantBase))
                }
            }
        }
        .navigationTitle("Проверка")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { onFinish(false) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить (\(model.checkedCount))", action: save)
                    .disabled(model.checkedCount == 0)
            }
        }
        .task {
            await model.enrich(using: ai)
        }
        .sheet(item: $openedPhoto) { page in
            PhotoViewer(photos: model.photos, index: page.index)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if model.duplicates > 0 || model.isWorking || model.failure != nil {
            Section {
                if model.duplicates > 0 {
                    Label("Пропущено повторов: \(model.duplicates)", systemImage: "arrow.uturn.right")
                        .foregroundStyle(.secondary)
                }
                if model.isWorking {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("AI подбирает перевод…")
                            .foregroundStyle(.secondary)
                    }
                }
                if let failure = model.failure {
                    failureView(failure)
                }
            }
        }
    }

    @ViewBuilder
    private func failureView(_ failure: AIError) -> some View {
        switch failure {
        case .notConfigured:
            Banner(text: "Перевод можно вписать вручную. AI подключается в настройках: нужен API-ключ Claude.", style: .info)
        case .offline:
            Banner(text: "Нет подключения к интернету. Перевод можно вписать вручную.", style: .info)
            retryButton
        default:
            Banner(text: failure.userMessage, style: .error)
            retryButton
        }
    }

    private var retryButton: some View {
        Button("Ещё раз") {
            Task { await model.enrich(using: ai) }
        }
        .disabled(model.isWorking)
    }

    private func save() {
        var photoID: String?
        if model.source == .photo, !model.photos.isEmpty,
           model.drafts.contains(where: { $0.include && !$0.ru.trimmed.isEmpty }) {
            photoID = app.photos.save(model.photos)
        }
        let result = DraftBuilder.save(model.drafts, existingKeys: cards.dedupKeys, photoId: photoID)
        if result.cards.isEmpty, let photoID {
            app.photos.delete(photoID)
        }
        cards.add(result.cards)
        toasts.show(result.message)
        onFinish(true)
    }
}

private struct DraftRow: View {
    @Binding var draft: CardDraft
    var isWaiting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Button {
                    draft.include.toggle()
                } label: {
                    Image(systemName: draft.include ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(draft.include ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(draft.include ? "Добавить: да" : "Добавить: нет")
                Text(draft.pl)
                    .font(Theme.polish(.title2, weight: .semibold))
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                if isWaiting {
                    ProgressView()
                }
            }

            if !badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.orange)
                    }
                }
            }

            if !draft.fix.isEmpty {
                HStack(spacing: 8) {
                    (Text("Похоже, пишется ") + Text(draft.fix).bold())
                        .font(.callout)
                    Spacer(minLength: 0)
                    Button("Исправить") { draft.applyFix() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            LabeledTextField(title: "Перевод", text: $draft.ru, polish: false)
            LabeledTextField(title: "Начальная форма", text: $draft.base)
            if !draft.baseCheck.isEmpty {
                Label {
                    Text(draft.baseCheck)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.footnote)
                .foregroundStyle(Color.orange)
            }
            LabeledTextField(title: "Пометка о форме", text: $draft.note)
            let grammar = [draft.form, draft.alternation].filter { !$0.isEmpty }.joined(separator: " · ")
            if !grammar.isEmpty {
                Text(grammar)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .opacity(draft.include ? 1 : 0.6)
    }

    private var badges: [String] {
        var result: [String] = []
        if draft.source == .photo { result.append("фото") }
        if draft.lowConfidence { result.append("неуверенно прочитано") }
        if !draft.isPolish { result.append("не похоже на польское") }
        if draft.missingFromReply && draft.ru.trimmed.isEmpty { result.append("нет перевода") }
        return result
    }
}
