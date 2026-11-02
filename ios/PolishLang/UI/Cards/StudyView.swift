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
                        ProgressView(value: model.progress)
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
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(card.ru)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if !card.form.isEmpty {
                        Text(card.form)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

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
                    .frame(height: 48)
                    .padding(.horizontal, 12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
    }

    private func hintRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.polish(.title3, weight: .semibold))
        }
        .padding(.horizontal, 4)
    }

    private func result(_ check: AnswerCheck, card: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            verdictLabel(check.verdict)
            if check.verdict != .correct && !check.given.isEmpty {
                DiffView(diff: check.diff)
            }
            Text(card.pl)
                .font(Theme.polish(.title, weight: .semibold))
                .textSelection(.enabled)
            if let line = card.formLine {
                Text(line)
                    .font(Theme.polish(.title3))
                    .foregroundStyle(.secondary)
            }
            if !card.note.isEmpty {
                Text(card.note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let example = card.example, !example.isEmpty {
                Text(example)
                    .font(Theme.polish(.callout))
                    .italic()
            }
            if check.verdict != .correct, !check.errorTypes.isEmpty, !check.given.isEmpty {
                Text("Ошибка: " + check.errorTypes.map(\.title).joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func verdictLabel(_ verdict: AnswerVerdict) -> some View {
        switch verdict {
        case .correct:
            Label(model.hintLevel > 0 ? "Верно, с подсказкой" : "Верно", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.green)
        case .almost:
            Label("Почти", systemImage: "circle.lefthalf.filled")
                .font(.headline)
                .foregroundStyle(Color.orange)
        case .wrong:
            Label(model.revealed ? "Ответ" : "Неверно", systemImage: "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.red)
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
                .buttonStyle(.bordered)
                Button {
                    submit(reveal: false)
                } label: {
                    Text("Проверить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.answer.trimmed.isEmpty)
                Text("Подсказка снижает оценку карточки.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.large)
        } else {
            Button {
                model.next()
            } label: {
                Text("Дальше")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
        return VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.green)
            Text("Готово")
                .font(.title.bold())
            HStack(spacing: 28) {
                stat("Верно", result.correct, .green)
                stat("Почти", result.almost, .orange)
                stat("С ошибкой", result.wrong, .red)
            }
            Button("Закрыть") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func stat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
        .font(Theme.polish(.title3))
    }

    private func row(_ title: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                return text + Text(String(typed)).foregroundStyle(Color.red).underline()
            case .missing:
                return text + Text(verbatim: "_").foregroundStyle(Color.red)
            case .extra(let typed):
                return text + Text(String(typed)).foregroundStyle(Color.red).strikethrough()
            }
        }
    }

    private var expected: Text {
        diff.reduce(Text(verbatim: "")) { text, op in
            switch op {
            case .same(let letter):
                return text + Text(String(letter))
            case .substitute(let wanted, _), .missing(let wanted):
                return text + Text(String(wanted)).foregroundStyle(Color.green).bold()
            case .extra:
                return text
            }
        }
    }
}
