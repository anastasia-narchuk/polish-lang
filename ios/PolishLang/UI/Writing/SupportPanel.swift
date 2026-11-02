import SwiftUI

/// "Опора для текста" (TZ 3, 4.3): the plan with Polish sentence starters, connectors, ideas
/// (the Russian thought first, the Polish collocation on a tap) and the learner's traps.
/// Its visibility follows the table of section 5.
struct SupportPanel: View {
    @Bindable var model: WorkspaceModel
    let traps: [TextErrorEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Опора для текста")
                    .heading(.title3)
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                if hasSupport {
                    Button(model.supportShown ? "Спрятать" : "Показать") {
                        withAnimation(.snappy(duration: 0.25)) { model.toggleSupport() }
                    }
                    .buttonStyle(.pill(.secondary, size: .small))
                }
            }
            .accessibilityAddTraits(.isHeader)
            if !model.supportShown && model.policy.plan == .hidden && hasSupport {
                Text("На экзамене опоры не будет. Сначала попробуй без неё: если откроешь, текст будет отмечен «с опорой» и не войдёт в прогноз.")
                    .font(.ui(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.supportShown {
                if !model.task.plan.isEmpty {
                    plan
                }
                if !model.task.connectors.isEmpty {
                    connectors
                }
                if !model.task.ideas.isEmpty {
                    ideas
                }
            }
            if model.policy.traps == .open && !traps.isEmpty {
                trapsList
            }
            if !hasSupport && traps.isEmpty {
                Text("Для этого задания опоры нет.")
                    .font(.ui(.footnote))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var hasSupport: Bool {
        model.policy.plan != .unavailable && (!model.task.plan.isEmpty || !model.task.connectors.isEmpty || !model.task.ideas.isEmpty)
    }

    private var plan: some View {
        VStack(alignment: .leading, spacing: 12) {
            caption("План")
            ForEach(Array(model.task.plan.enumerated()), id: \.offset) { index, part in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index + 1) · \(part.ru)")
                        .font(.ui(.headline))
                        .foregroundStyle(Theme.text)
                    if !part.phrases.isEmpty {
                        Text(part.phrases.joined(separator: " · "))
                            .font(Theme.polish(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var connectors: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Связки")
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(model.task.connectors, id: \.self) { connector in
                    Text(connector)
                        .font(Theme.polish(.subheadline, weight: .medium))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(Theme.fill, in: Capsule())
                        .foregroundStyle(Theme.text)
                }
            }
        }
    }

    private var ideas: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Идеи")
            Text("Сначала вспомни, как это по-польски, потом нажми и сверься. Подсмотрено: \(model.support.ideasRevealed) из \(model.task.ideas.count).")
                .font(.ui(.footnote))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Array(model.task.ideas.enumerated()), id: \.offset) { index, idea in
                    let revealed = model.revealedIdeas.contains(index)
                    Button {
                        model.revealIdea(index)
                    } label: {
                        HStack(spacing: 4) {
                            Text(idea.ru)
                                .foregroundStyle(Theme.text)
                            if revealed {
                                Text("→ " + idea.pl)
                                    .font(Theme.polish(.subheadline, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        .font(.ui(.subheadline))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(revealed ? Theme.surface : Theme.fill, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(revealed ? Theme.line : Color.clear, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(revealed)
                    .accessibilityHint(revealed ? "" : "Показать польский вариант")
                }
            }
        }
    }

    private var trapsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            caption("Мои ловушки")
            ForEach(traps) { trap in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.warning)
                        .accessibilityHidden(true)
                    Text(trap.trapLine)
                        .font(Theme.polish(.subheadline))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.ui(.footnote, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
    }
}
