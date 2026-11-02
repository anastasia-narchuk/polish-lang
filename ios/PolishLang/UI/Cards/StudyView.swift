import SwiftUI

/// Review (TZ 1, section 6): the front shows the translation of the form, the answer is typed,
/// compared strictly with diacritics, and afterwards "rzeka → rzece (k→c)" is shown.
struct StudyView: View {
    @Bindable var model: StudyModel
    @Environment(\.dismiss) private var dismiss
    @Environment(CardStore.self) private var cards
    @Environment(MistakeStore.self) private var mistakes

    var body: some View {
        NavigationStack {
            Group {
                if model.isFinished {
                    summary
                } else if let card = model.current {
                    cardView(card)
                }
            }
            .navigationTitle(model.isFinished ? "Итог" : "Повторение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закончить") { dismiss() }
                }
                if !model.isFinished {
                    ToolbarItem(placement: .principal) {
                        ProgressBar(value: model.progress)
                            .frame(width: 140)
                            .accessibilityLabel("Пройдено карточек")
                    }
                }
            }
        }
    }

    // MARK: Card

    private func cardView(_ card: Flashcard) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text(card.ru)
                        .heading(.title)
                        .foregroundStyle(Theme.studyFeature.accent)
                        .multilineTextAlignment(.center)
                    if !card.form.isEmpty {
                        Text(card.form)
                            .font(.ui(.subheadline))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(.vertical, 32)
                .padding(.horizontal, Theme.Space.card)
                .background(Theme.studyFeature.background, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))

                if let base = model.baseHint {
                    hintRow("Начальная форма", base)
                }
                if let letters = model.lettersHint {
                    hintRow("Начинается с", letters)
                }

                VStack(spacing: 10) {
                    PolishTextField(
                        text: $model.answer,
                        placeholder: "Напиши по-польски",
                        isEditable: model.stage == .answering,
                        focusTrigger: model.step,
                        onSubmit: submitOrNext
                    )
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                            .strokeBorder(model.stage == .answering ? Theme.ink : Theme.border, lineWidth: model.stage == .answering ? 2 : 1)
                    }
                    if model.stage == .answering {
                        PolishLettersBar { letter in
                            model.answer += letter
                        }
                    }
                }

                if model.stage == .checked, let check = model.check {
                    result(check, card: card)
                }

                buttons
            }
            .padding(Theme.Space.screen)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
    }

    private func hintRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.ui(.title3, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }

    private func result(_ check: AnswerCheck, card: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            verdictLabel(check.verdict)
            if check.verdict != .correct && !check.given.isEmpty {
                DiffView(diff: check.diff)
            }
            Text(card.pl)
                .heading(.title)
                .textSelection(.enabled)
            if let line = card.formLine {
                Text(line)
                    .font(.ui(.title3, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
            if !card.note.isEmpty {
                Text(card.note)
                    .font(.ui(.callout))
                    .foregroundStyle(Theme.textSecondary)
            }
            if let example = card.example, !example.isEmpty {
                Text(example)
                    .font(.ui(.callout))
                    .italic()
            }
            if check.verdict != .correct, !check.errorTypes.isEmpty, !check.given.isEmpty {
                HStack(spacing: 6) {
                    ForEach(check.errorTypes.map(\.title), id: \.self) { title in
                        Tag(text: title, style: .negative)
                    }
                }
            }
        }
        .cardBackground()
    }

    @ViewBuilder
    private func verdictLabel(_ verdict: AnswerVerdict) -> some View {
        switch verdict {
        case .correct:
            Label(model.hintLevel > 0 ? "Верно, с подсказкой" : "Верно", systemImage: "checkmark.circle.fill")
                .font(.ui(.headline))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.positiveFill, in: Capsule())
                .foregroundStyle(Theme.positive)
        case .almost:
            Label("Почти", systemImage: "circle.lefthalf.filled")
                .font(.ui(.headline))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.warningFill, in: Capsule())
                .foregroundStyle(Theme.warning)
        case .wrong:
            Label(model.revealed ? "Ответ" : "Неверно", systemImage: "xmark.circle.fill")
                .font(.ui(.headline))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.negativeFill, in: Capsule())
                .foregroundStyle(Theme.negative)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if model.stage == .answering {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        model.nextHint()
                    } label: {
                        Label("Подсказка", systemImage: "lightbulb")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!model.canHint)
                    Button {
                        submit(reveal: true)
                    } label: {
                        Text("Не помню")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.pill(.secondary))
                Button {
                    submit(reveal: false)
                } label: {
                    Text("Проверить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.primary))
                .disabled(model.answer.trimmed.isEmpty)
                Text("Подсказка снижает оценку карточки.")
                    .font(.ui(.footnote))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            Button {
                model.next()
            } label: {
                Text("Дальше")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.primary))
        }
    }

    private func submit(reveal: Bool) {
        guard let outcome = model.submit(reveal: reveal) else { return }
        cards.update(outcome.card)
        if let mistake = outcome.mistake {
            mistakes.record(mistake)
        }
    }

    private func submitOrNext() {
        if model.stage == .checked {
            model.next()
        } else if !model.answer.trimmed.isEmpty {
            submit(reveal: false)
        }
    }

    // MARK: Summary

    private var summary: some View {
        let result = model.summary
        return VStack(spacing: 24) {
            IconCircle(systemName: "checkmark", size: 88, tint: Theme.onBright, fill: Theme.bright)
            Text("Готово")
                .heading(.largeTitle)
            HStack(spacing: 12) {
                stat("Верно", result.correct, Theme.positive, Theme.positiveFill)
                stat("Почти", result.almost, Theme.warning, Theme.warningFill)
                stat("С ошибкой", result.wrong, Theme.negative, Theme.negativeFill)
            }
            Button {
                dismiss()
            } label: {
                Text("Закрыть")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.primary))
        }
        .padding(Theme.Space.screen)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }

    private func stat(_ title: String, _ value: Int, _ color: Color, _ fill: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .heading(.title)
                .foregroundStyle(color)
            Text(title)
                .font(.ui(.footnote, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

/// The answer and the expected form letter by letter: wrong letters in red, missing ones in green.
struct DiffView: View {
    let diff: [DiffOp]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Ответ", given)
            row("Нужно", expected)
        }
        .font(.ui(.title3, weight: .medium))
    }

    private func row(_ title: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.ui(.caption))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, alignment: .leading)
            text
        }
    }

    private var given: Text {
        diff.reduce(Text(verbatim: "")) { text, op in
            switch op {
            case .same(let letter):
                return text + Text(String(letter))
            case .substitute(_, let typed):
                return text + Text(String(typed)).foregroundStyle(Theme.negative).underline()
            case .missing:
                return text + Text(verbatim: "_").foregroundStyle(Theme.negative)
            case .extra(let typed):
                return text + Text(String(typed)).foregroundStyle(Theme.negative).strikethrough()
            }
        }
    }

    private var expected: Text {
        diff.reduce(Text(verbatim: "")) { text, op in
            switch op {
            case .same(let letter):
                return text + Text(String(letter))
            case .substitute(let wanted, _), .missing(let wanted):
                return text + Text(String(wanted)).foregroundStyle(Theme.positive).bold()
            case .extra:
                return text
            }
        }
    }
}
