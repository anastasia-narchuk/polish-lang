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
                    reviewBlock
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: Theme.Space.screen, bottom: 16, trailing: Theme.Space.screen))
                    NavigationLink {
                        MistakesView()
                    } label: {
                        InfoRow(
                            icon: "exclamationmark.bubble",
                            title: "Банк ошибок",
                            subtitle: mistakes.mistakes.isEmpty ? "Пока пусто" : Russian.plural(mistakes.mistakes.count, "запись", "записи", "записей")
                        )
                    }
                    .themedRow()
                    SectionHeader(Russian.plural(cards.cards.count, "карточка", "карточки", "карточек"))
                        .padding(.top, 24)
                        .padding(.bottom, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.screen, bottom: 0, trailing: Theme.Space.screen))
                    ForEach(filteredCards) { card in
                        NavigationLink(value: card.id) {
                            CardRow(card: card)
                        }
                        .themedRow()
                    }
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .screenBackground()
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
                    EmptyState(icon: "trash", title: "Карточка удалена", text: "Её больше нет в тетради.")
                        .screenBackground()
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
        let learned = cards.cards.filter { $0.box >= Leitner.maxBox }.count
        FeatureCard(feature: Theme.cardsFeature, title: due > 0 ? "К повторению: \(due)" : "Всё повторено") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressBar(value: Double(learned) / Double(max(1, cards.cards.count)), tint: Theme.cardsFeature.accent, track: Color.white.opacity(0.14))
                Text("Выучено \(learned) из \(cards.cards.count)")
                    .font(.ui(.footnote))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            if due == 0, let next = StudyPlanner.nextDueDate(cards.cards, now: Date()) {
                Text("Следующее повторение " + next.formatted(.relative(presentation: .named)))
                    .font(.ui(.subheadline))
            }
            if due > 0 {
                Button {
                    startStudy(dueOnly: true)
                } label: {
                    Label("Повторить", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.primary))
            } else {
                Button {
                    startStudy(dueOnly: false)
                } label: {
                    Label("Потренироваться ещё", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.inverse))
            }
        }
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
        EmptyState(
            icon: "rectangle.on.rectangle.angled",
            title: "Пока нет карточек",
            text: "Добавь слова в той форме, в какой они встретились: по одному, списком или с фото тетради. Или сохрани их прямо из текста во вкладке «Чтение»."
        ) {
            Button("Добавить слова") { showAdd = true }
                .buttonStyle(.pill(.primary))
        }
        .screenBackground()
    }
}

struct CardRow: View {
    let card: Flashcard

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.pl)
                    .font(.ui(.headline))
                    .foregroundStyle(Theme.text)
                Text(card.ru)
                    .font(.ui(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            BoxIndicator(box: card.box)
        }
        .padding(.vertical, 14)
        .frame(minHeight: 64)
    }
}

/// How far the card has moved through the Leitner boxes.
struct BoxIndicator: View {
    let box: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<Leitner.maxBox, id: \.self) { index in
                Capsule()
                    .fill(index < box ? Theme.bright : Theme.track)
                    .frame(width: 10, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Выучено на \(box) из \(Leitner.maxBox)")
    }
}

extension View {
    /// A row of a plain list on the white screen, with hairline separators.
    func themedRow() -> some View {
        listRowBackground(Theme.background)
            .listRowSeparatorTint(Theme.line)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.screen, bottom: 0, trailing: Theme.Space.screen))
    }
}
