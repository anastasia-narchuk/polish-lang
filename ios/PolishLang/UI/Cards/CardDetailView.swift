import SwiftUI

/// One card: the form stays as saved, the translation and notes can be edited.
struct CardDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(CardStore.self) private var cards
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Flashcard
    @State private var deleteArmed = false
    @State private var openedPhoto: PhotoPage?
    @State private var photos: [Data] = []
    private let original: Flashcard

    init(card: Flashcard) {
        original = card
        _draft = State(initialValue: card)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.pl)
                        .heading(.largeTitle)
                        .textSelection(.enabled)
                    if let line = draft.formLine {
                        Text(line)
                            .font(.ui(.title3, weight: .regular))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    LabeledTextField(title: "Перевод", text: $draft.ru, polish: false)
                    LabeledTextField(title: "Начальная форма", text: $draft.base)
                    LabeledTextField(title: "Грамматическая форма", text: $draft.form)
                    LabeledTextField(title: "Чередование", text: $draft.alternation)
                    LabeledTextField(title: "Пометка", text: $draft.note)
                }

                if let example = draft.example, !example.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пример из текста")
                            .font(.ui(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(example)
                            .font(.ui(.body))
                            .textSelection(.enabled)
                        if let exampleRu = draft.exampleRu, !exampleRu.isEmpty {
                            Text(exampleRu)
                                .font(.ui(.callout))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .cardBackground()
                }

                if !photos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Фото")
                        PhotoStrip(photos: photos) { index in
                            openedPhoto = PhotoPage(index: index)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Повторение")
                        .heading(.title3)
                        .padding(.bottom, 12)
                    VStack(alignment: .leading, spacing: 8) {
                        ValueRow(title: "Уровень запоминания", value: "\(draft.box) из \(Leitner.maxBox)")
                        ProgressBar(value: Double(draft.box) / Double(Leitner.maxBox))
                            .padding(.bottom, 8)
                    }
                    Hairline()
                    ValueRow(title: "Следующее повторение", value: draft.due.formatted(.dateTime.day().month().hour().minute()))
                    Hairline()
                    ValueRow(title: "Верно / с ошибкой", value: "\(draft.right) / \(draft.wrong)")
                    Hairline()
                    ValueRow(title: "Добавлена", value: draft.created.formatted(.dateTime.day().month().year()))
                    Hairline()
                    ValueRow(title: "Источник", value: draft.source.title)
                }
                .cardBackground(radius: Theme.Radius.hero)

                Button(role: .destructive) {
                    if deleteArmed {
                        app.deleteCards(ids: [draft.id])
                        dismiss()
                    } else {
                        deleteArmed = true
                    }
                } label: {
                    Text(deleteArmed ? "Точно удалить?" : "Удалить карточку")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.destructive))
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Карточка")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if draft != original, cards.card(id: draft.id) != nil {
                cards.update(draft)
            }
        }
        .sheet(item: $openedPhoto) { page in
            PhotoViewer(photos: photos, index: page.index)
        }
        .task {
            guard let photoID = draft.photoId else { return }
            photos = app.photos.photos(for: photoID).compactMap { try? Data(contentsOf: $0) }
        }
    }
}
