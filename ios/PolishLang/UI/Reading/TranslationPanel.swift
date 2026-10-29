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
                    .font(.headline)
                Spacer()
                Button("Готово") { model.panelPresented = false }
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let selection = model.selection {
                        Text(selection.text)
                            .font(Theme.polish(.title, weight: .semibold))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        content(for: selection)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.background)
    }

    @ViewBuilder
    private func content(for selection: ReaderSelection) -> some View {
        switch model.translation {
        case .idle, .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Перевожу…")
                    .foregroundStyle(.secondary)
            }
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
            .font(.title3)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 6) {
            if !translation.base.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("начальная форма:")
                        .foregroundStyle(.secondary)
                    Text(translation.base)
                        .font(Theme.polish(.body, weight: .semibold))
                    if !translation.alternation.isEmpty {
                        Text("(" + translation.alternation + ")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            let grammar = [translation.pos, translation.form].filter { !$0.isEmpty }.joined(separator: " · ")
            if !grammar.isEmpty {
                Text(grammar)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)

        if !translation.note.isEmpty {
            Banner(text: translation.note, style: .info)
        }

        if !translation.sentenceRu.isEmpty {
            DisclosureGroup("Перевод предложения", isExpanded: $showSentence) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selection.sentence)
                        .font(Theme.polish(.callout))
                        .foregroundStyle(.secondary)
                    Text(translation.sentenceRu)
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
        }

        Divider()
        addToCards(translation)
    }

    @ViewBuilder
    private func addToCards(_ translation: WordTranslation) -> some View {
        if model.canSaveBaseForm {
            Toggle(isOn: $model.saveBaseForm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Сохранить начальную форму вместо этой")
                    if model.saveBaseForm {
                        baseFormStatus(translation)
                            .font(.footnote)
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
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(candidate == nil || alreadySaved)

        if let candidate {
            Text("В карточку: " + candidate.pl + " — " + candidate.ru)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func baseFormStatus(_ translation: WordTranslation) -> some View {
        switch model.baseForm {
        case .idle, .loading:
            Text("Перевожу начальную форму…")
                .foregroundStyle(.secondary)
        case .loaded(let base):
            Text(translation.base + " — " + base.ru)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}
