import SwiftUI

struct CardsTab: View {
    @Environment(AppModel.self) private var app
    @Environment(CardStore.self) private var cards
    @Environment(MistakeStore.self) private var mistakes
    @State private var showAdd = false
    @State private var study: StudyModel?
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                if !cards.cards.isEmpty {
                    Section {
                        reviewBlock
                    }
                    Section {
                        NavigationLink {
                            MistakesView()
                        } label: {
                            LabeledContent {
                                Text("\(mistakes.mistakes.count)")
                            } label: {
                                Label("Банк ошибок", systemImage: "exclamationmark.bubble")
                            }
                        }
                    }
                    Section {
                        ForEach(filteredCards) { card in
                            NavigationLink(value: card.id) {
                                CardRow(card: card)
                            }
                        }
                        .onDelete(perform: delete)
                    } header: {
                        Text(Russian.plural(cards.cards.count, "карточка", "карточки", "карточек"))
                    }
                }
            }
            .navigationTitle("Карточки")
            .searchable(text: $search, prompt: "Поиск по карточкам")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Добавить слова", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                if let card = cards.card(id: id) {
                    CardDetailView(card: card)
                } else {
                    ContentUnavailableView("Карточка удалена", systemImage: "trash")
                }
            }
            .overlay {
                if cards.cards.isEmpty {
                    emptyState
                }
            }
            .sheet(isPresented: $showAdd) {
                AddWordsView()
            }
            .fullScreenCover(item: $study) { model in
                StudyView(model: model)
            }
        }
    }

    private var filteredCards: [Flashcard] {
        let query = search.trimmed.lowercased()
        guard !query.isEmpty else { return cards.cards }
        let folded = PolishText.fold(query)
        return cards.cards.filter { card in
            PolishText.fold(card.pl.lowercased()).contains(folded)
                || card.ru.lowercased().contains(query)
                || PolishText.fold(card.base.lowercased()).contains(folded)
        }
    }

    private func delete(at offsets: IndexSet) {
        let visible = filteredCards
        app.deleteCards(ids: Set(offsets.map { visible[$0].id }))
    }

    @ViewBuilder
    private var reviewBlock: some View {
        let due = cards.dueCount()
        VStack(alignment: .leading, spacing: 10) {
            if due > 0 {
                Text("К повторению: \(due)")
                    .font(.title3.weight(.semibold))
                Button {
                    startStudy(dueOnly: true)
                } label: {
                    Label("Повторить", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("Всё повторено")
                    .font(.title3.weight(.semibold))
                if let next = StudyPlanner.nextDueDate(cards.cards, now: Date()) {
                    Text("Следующее повторение " + next.formatted(.relative(presentation: .named)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    startStudy(dueOnly: false)
                } label: {
                    Label("Потренироваться ещё", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(.vertical, 6)
    }

    private func startStudy(dueOnly: Bool) {
        var generator = SystemRandomNumberGenerator()
        let selected = dueOnly
            ? StudyPlanner.dueCards(cards.cards, now: Date(), limit: 20)
            : StudyPlanner.practiceCards(cards.cards, limit: 10, using: &generator)
        guard !selected.isEmpty else { return }
        study = StudyModel(cards: selected)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Пока нет карточек", systemImage: "rectangle.on.rectangle.angled")
        } description: {
            Text("Добавь слова в той форме, в какой они встретились: по одному, списком или с фото тетради. Или сохрани их прямо из текста во вкладке «Чтение».")
        } actions: {
            Button("Добавить слова") { showAdd = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct CardRow: View {
    let card: Flashcard

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.pl)
                    .font(Theme.polish(.headline))
                Spacer(minLength: 8)
                BoxIndicator(box: card.box)
            }
            Text(card.ru)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

/// How far the card has moved through the Leitner boxes.
struct BoxIndicator: View {
    let box: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Leitner.maxBox, id: \.self) { index in
                Capsule()
                    .fill(index < box ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Выучено на \(box) из \(Leitner.maxBox)")
    }
}
