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
        Form {
            Section {
                Text(draft.pl)
                    .font(Theme.polish(.largeTitle, weight: .semibold))
                    .textSelection(.enabled)
                if let line = draft.formLine {
                    Text(line)
                        .font(Theme.polish(.title3))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Перевод") {
                TextField("Перевод", text: $draft.ru, axis: .vertical)
            }

            Section("Форма") {
                LabeledTextField(title: "Начальная форма", text: $draft.base)
                LabeledTextField(title: "Грамматическая форма", text: $draft.form)
                LabeledTextField(title: "Чередование", text: $draft.alternation)
                LabeledTextField(title: "Пометка", text: $draft.note)
            }

            if let example = draft.example, !example.isEmpty {
                Section("Пример из текста") {
                    Text(example)
                        .font(Theme.polish(.body))
                        .textSelection(.enabled)
                    if let exampleRu = draft.exampleRu, !exampleRu.isEmpty {
                        Text(exampleRu)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !photos.isEmpty {
                Section("Фото") {
                    PhotoStrip(photos: photos) { index in
                        openedPhoto = PhotoPage(index: index)
                    }
                }
            }

            Section("Повторение") {
                LabeledContent("Уровень запоминания", value: "\(draft.box) из \(Leitner.maxBox)")
                LabeledContent("Следующее повторение") {
                    Text(draft.due, format: .dateTime.day().month().hour().minute())
                }
                LabeledContent("Верно / с ошибкой", value: "\(draft.right) / \(draft.wrong)")
                LabeledContent("Добавлена") {
                    Text(draft.created, format: .dateTime.day().month().year())
                }
                LabeledContent("Источник", value: draft.source.title)
            }

            Section {
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
            }
        }
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
