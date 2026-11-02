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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !model.photos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        PhotoStrip(photos: model.photos) { index in
                            openedPhoto = PhotoPage(index: index)
                        }
                        Text("Сверь слова с фото: нажми на снимок, чтобы увеличить.")
                            .font(.ui(.footnote))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                statusSection
                ForEach($model.drafts) { $draft in
                    DraftRow(draft: $draft, isWaiting: model.isWorking && !draft.answered && draft.needsAI(wantBase: model.wantBase))
                        .cardBackground(padding: 20)
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
            VStack(alignment: .leading, spacing: 12) {
                if model.duplicates > 0 {
                    Label("Пропущено повторов: \(model.duplicates)", systemImage: "arrow.uturn.right")
                        .font(.ui(.callout, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                if model.isWorking {
                    WorkingRow(text: "AI подбирает перевод…")
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
        .buttonStyle(.pill(.secondary, size: .medium))
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    draft.include.toggle()
                } label: {
                    Image(systemName: draft.include ? "checkmark" : "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(draft.include ? Theme.onBright : Theme.ink)
                        .frame(width: 36, height: 36)
                        .background(draft.include ? Theme.bright : Theme.fill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(draft.include ? "Добавить: да" : "Добавить: нет")
                Text(draft.pl)
                    .heading(.title2)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                if isWaiting {
                    ProgressView()
                        .tint(Theme.ink)
                }
            }

            if !badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(badges, id: \.self) { badge in
                        Tag(text: badge, style: .warning)
                    }
                }
            }

            if !draft.fix.isEmpty {
                HStack(spacing: 8) {
                    (Text("Похоже, пишется ") + Text(draft.fix).fontWeight(.semibold))
                        .font(.ui(.callout))
                    Spacer(minLength: 0)
                    Button("Исправить") { draft.applyFix() }
                        .buttonStyle(.pill(.primary, size: .small))
                }
                .padding(12)
                .background(Theme.warningFill, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            }

            LabeledTextField(title: "Перевод", text: $draft.ru, polish: false)
            LabeledTextField(title: "Начальная форма", text: $draft.base)
            if !draft.baseCheck.isEmpty {
                Label {
                    Text(draft.baseCheck)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.ui(.footnote))
                .foregroundStyle(Theme.warning)
            }
            LabeledTextField(title: "Пометка о форме", text: $draft.note)
            let grammar = [draft.form, draft.alternation].filter { !$0.isEmpty }.joined(separator: " · ")
            if !grammar.isEmpty {
                Text(grammar)
                    .font(.ui(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
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
