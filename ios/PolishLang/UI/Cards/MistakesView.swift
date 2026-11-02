import SwiftUI

/// The mistake bank: how often each kind of mistake happens and the latest answers.
struct MistakesView: View {
    @Environment(MistakeStore.self) private var mistakes
    @State private var clearArmed = false

    var body: some View {
        List {
            if !mistakes.mistakes.isEmpty {
                Section("По типам") {
                    ForEach(mistakes.counts(), id: \.type) { item in
                        LabeledContent(item.type.title, value: "\(item.count)")
                    }
                }
                Section("Последние") {
                    ForEach(mistakes.mistakes.prefix(100)) { mistake in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(mistake.expected)
                                    .font(Theme.polish(.headline))
                                Spacer()
                                Text(mistake.date, format: .dateTime.day().month())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 6) {
                                Text(mistake.given)
                                    .font(Theme.polish(.callout))
                                    .strikethrough()
                                    .foregroundStyle(Color.red)
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(mistake.types.map(\.title).joined(separator: ", "))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        if clearArmed {
                            mistakes.clear()
                            clearArmed = false
                        } else {
                            clearArmed = true
                        }
                    } label: {
                        Text(clearArmed ? "Точно очистить?" : "Очистить банк ошибок")
                    }
                }
            }
        }
        .navigationTitle("Банк ошибок")
        .overlay {
            if mistakes.mistakes.isEmpty {
                ContentUnavailableView(
                    "Ошибок пока нет",
                    systemImage: "checkmark.seal",
                    description: Text("Сюда попадают ответы с ошибками из повторения, с типом: ó/u, rz/ż, ch/h, ą/ę, ogonki, окончание.")
                )
            }
        }
    }
}
