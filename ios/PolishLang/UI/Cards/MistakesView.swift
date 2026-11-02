import SwiftUI

/// The mistake bank: how often each kind of mistake happens and the latest answers.
struct MistakesView: View {
    @Environment(MistakeStore.self) private var mistakes
    @State private var clearArmed = false

    var body: some View {
        ScrollView {
            if !mistakes.mistakes.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.section) {
                    byType
                    latest
                    Button(role: .destructive) {
                        if clearArmed {
                            mistakes.clear()
                            clearArmed = false
                        } else {
                            clearArmed = true
                        }
                    } label: {
                        Text(clearArmed ? "Точно очистить?" : "Очистить банк ошибок")
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
        }
        .screenBackground()
        .navigationTitle("Банк ошибок")
        .overlay {
            if mistakes.mistakes.isEmpty {
                EmptyState(
                    icon: "checkmark.seal",
                    title: "Ошибок пока нет",
                    text: "Сюда попадают ответы с ошибками из повторения, с типом: ó/u, rz/ż, ch/h, ą/ę, ogonki, окончание."
                )
            }
        }
    }

    /// Like Wise's cost breakdown: a bar per type.
    private var byType: some View {
        let counts = mistakes.counts()
        let top = max(1, counts.map { $0.count }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 20) {
            Text("По типам")
                .heading(.title3)
            ForEach(counts, id: \.type) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.type.title)
                            .font(.ui(.headline))
                        Spacer()
                        Text("\(item.count)")
                            .font(.ui(.body, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .monospacedDigit()
                    }
                    ProgressBar(value: Double(item.count) / Double(top))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardBackground(radius: Theme.Radius.hero)
    }

    private var latest: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Последние")
                .padding(.bottom, 8)
            ForEach(Array(mistakes.mistakes.prefix(100).enumerated()), id: \.element.id) { index, mistake in
                if index > 0 {
                    Hairline()
                }
                HStack(alignment: .top, spacing: 16) {
                    IconCircle(systemName: "xmark", tint: Theme.negative, fill: Theme.negativeFill)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(mistake.expected)
                                .font(.ui(.headline))
                            Spacer()
                            Text(mistake.date, format: .dateTime.day().month())
                                .font(.ui(.caption))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        HStack(spacing: 6) {
                            Text(mistake.given)
                                .font(.ui(.callout))
                                .strikethrough()
                                .foregroundStyle(Theme.negative)
                            Text("·")
                                .foregroundStyle(Theme.textTertiary)
                            Text(mistake.types.map(\.title).joined(separator: ", "))
                                .font(.ui(.callout))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
