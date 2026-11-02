import SwiftUI

/// Translation of the picked word or phrase: a column on the right on iPad, a bottom sheet on
/// iPhone (TZ 2, section 5). No NavigationStack inside: the column lives in the reader's stack.
struct TranslationPanel: View {
    @Bindable var model: ReaderModel
    @Environment(AIService.self) private var ai
    @Environment(ReadingSession.self) private var session
    @Environment(CardStore.self) private var cards
    @State private var showSentence = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Перевод")
                    .heading(.title3)
                Spacer()
                Button("Готово") { model.panelPresented = false }
                    .buttonStyle(.pill(.secondary, size: .small))
            }
            .padding(.horizontal, Theme.Space.card)
            .padding(.top, 20)
            .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let selection = model.selection {
                        Text(selection.text)
                            .heading(.title)
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        content(for: selection)
                    }
                }
                .padding(Theme.Space.card)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .screenBackground()
    }

    @ViewBuilder
    private func content(for selection: ReaderSelection) -> some View {
        switch model.translation {
        case .idle, .loading:
            WorkingRow(text: "Перевожу…")
        case .failed(let message, let retryAfter):
            Banner(text: message, style: .error)
            if ai.hasKey {
                RetryButton(retryAfter: retryAfter) {
                    model.retry(ai: ai, session: session)
                }
            }
        case .loaded(let translation):
            loaded(translation, selection: selection)
        }
    }

    @ViewBuilder
    private func loaded(_ translation: WordTranslation, selection: ReaderSelection) -> some View {
        Text(translation.ru)
            .font(.ui(.title3, weight: .regular))
            .foregroundStyle(Theme.text)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 0) {
            if !translation.base.isEmpty {
                ValueRow(
                    title: "Начальная форма",
                    value: translation.alternation.isEmpty ? translation.base : translation.base + " (" + translation.alternation + ")"
                )
            }
            let grammar = [translation.pos, translation.form].filter { !$0.isEmpty }.joined(separator: " · ")
            if !grammar.isEmpty {
                if !translation.base.isEmpty { Hairline() }
                ValueRow(title: "Форма", value: grammar)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))

        if !translation.note.isEmpty {
            Banner(text: translation.note, style: .info)
        }

        if !translation.sentenceRu.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { showSentence.toggle() }
                } label: {
                    HStack {
                        Text("Перевод предложения")
                            .font(.ui(.headline))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Image(systemName: showSentence ? "minus" : "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 40, height: 40)
                            .background(Theme.fill, in: Circle())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(showSentence ? "открыто" : "закрыто")
                if showSentence {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selection.sentence)
                            .font(.ui(.callout))
                            .foregroundStyle(Theme.textSecondary)
                        Text(translation.sentenceRu)
                            .font(.ui(.callout))
                            .foregroundStyle(Theme.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
            }
        }

        Hairline()
        addToCards(translation)
    }

    @ViewBuilder
    private func addToCards(_ translation: WordTranslation) -> some View {
        if model.canSaveBaseForm {
            Toggle(isOn: $model.saveBaseForm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Сохранить начальную форму вместо этой")
                        .font(.ui(.body))
                    if model.saveBaseForm {
                        baseFormStatus(translation)
                            .font(.ui(.footnote))
                    }
                }
            }
            .onChange(of: model.saveBaseForm) { _, isOn in
                if isOn { model.loadBaseForm(ai: ai) }
            }
        }

        let candidate = model.candidateCard()
        let alreadySaved = candidate.map { cards.contains(form: $0.pl) } ?? false
        Button {
            if let candidate { cards.add([candidate]) }
        } label: {
            Label(alreadySaved ? "Уже в карточках" : "Добавить в карточки",
                  systemImage: alreadySaved ? "checkmark" : "plus.rectangle.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pill(.primary))
        .disabled(candidate == nil || alreadySaved)

        if let candidate {
            Text("В карточку: " + candidate.pl + " — " + candidate.ru)
                .font(.ui(.footnote))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private func baseFormStatus(_ translation: WordTranslation) -> some View {
        switch model.baseForm {
        case .idle, .loading:
            Text("Перевожу начальную форму…")
                .foregroundStyle(Theme.textSecondary)
        case .loaded(let base):
            Text(translation.base + " — " + base.ru)
                .foregroundStyle(Theme.textSecondary)
        case .failed(let message):
            Text(message)
                .foregroundStyle(Theme.negative)
        }
    }
}
