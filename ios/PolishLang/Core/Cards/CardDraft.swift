import Foundation

/// A row of the check screen before saving (TZ 1, section 3).
struct CardDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    /// The form exactly as written; changes only when the learner taps "Исправить".
    var pl: String
    var ru: String
    var base: String
    var form = ""
    var alternation = ""
    var note = ""
    /// Suggested spelling of the same form, never applied silently.
    var fix = ""
    /// What is wrong with the learner's own base form, if anything.
    var baseCheck = ""
    var isPolish = true
    /// Photo reading the model was unsure about.
    var lowConfidence = false
    var include: Bool
    /// The base form was given by the learner: AI only checks it.
    let baseFromLearner: Bool
    /// AI did not return this row (TZ 1, 7: "нет перевода").
    var missingFromReply = false
    /// AI has answered for this row; "Ещё раз" resends only the rows without an answer.
    var answered = false
    let source: CardSource

    init(entry: ParsedEntry, source: CardSource, lowConfidence: Bool = false) {
        self.id = UUID()
        self.pl = entry.pl
        self.ru = entry.ru
        self.base = entry.base
        self.baseFromLearner = !entry.base.isEmpty
        self.lowConfidence = lowConfidence
        self.include = !lowConfidence
        self.source = source
    }

    /// The row has to go to AI: no translation, or no base form while base forms are wanted.
    func needsAI(wantBase: Bool) -> Bool {
        ru.trimmed.isEmpty || (wantBase && base.trimmed.isEmpty)
    }

    var enrichInput: EnrichInput {
        EnrichInput(pl: pl, base: baseFromLearner ? base : "")
    }

    /// Fills what is still empty. The learner's own text (translation, base form, edits made
    /// while AI was answering) is never overwritten.
    mutating func apply(_ result: EnrichResult?) {
        guard let result else {
            missingFromReply = ru.trimmed.isEmpty
            return
        }
        answered = true
        missingFromReply = false
        if ru.trimmed.isEmpty { ru = result.ru }
        if baseFromLearner {
            baseCheck = result.baseCheck
        } else if base.trimmed.isEmpty {
            base = result.base
        }
        if form.isEmpty { form = result.form }
        if alternation.isEmpty { alternation = result.alternation }
        if note.isEmpty { note = result.note }
        let suggestion = PolishText.nfc(result.fix.trimmed)
        fix = suggestion.isEmpty || suggestion == pl ? "" : suggestion
        if !result.isPolish {
            isPolish = false
            include = false
        }
    }

    mutating func applyFix() {
        guard !fix.isEmpty else { return }
        pl = fix
        fix = ""
    }
}

struct DraftPreparation: Sendable {
    var drafts: [CardDraft]
    /// Forms already in the cards or repeated in the input ("Пропущено повторов: N").
    var duplicates: Int
}

struct DraftSaveResult: Sendable {
    var cards: [Flashcard]
    var skippedWithoutTranslation: Int
    var skippedDuplicates: Int

    /// "Добавлено: X. Без перевода не сохраняю".
    var message: String {
        var text = "Добавлено: \(cards.count)"
        if skippedWithoutTranslation > 0 { text += ". Без перевода не сохраняю" }
        return text
    }
}

enum DraftBuilder {
    static func prepare(_ drafts: [CardDraft], existingKeys: Set<String>) -> DraftPreparation {
        var seen = existingKeys
        var kept: [CardDraft] = []
        var duplicates = 0
        for draft in drafts {
            let key = PolishText.dedupKey(draft.pl)
            guard !key.isEmpty else { continue }
            if seen.contains(key) {
                duplicates += 1
            } else {
                seen.insert(key)
                kept.append(draft)
            }
        }
        return DraftPreparation(drafts: kept, duplicates: duplicates)
    }

    /// Cards from the checked rows. Rows without a translation are not saved; a form that
    /// became a duplicate after "Исправить" is skipped.
    static func save(_ drafts: [CardDraft], existingKeys: Set<String>, photoId: String?, now: Date = Date()) -> DraftSaveResult {
        var seen = existingKeys
        var result = DraftSaveResult(cards: [], skippedWithoutTranslation: 0, skippedDuplicates: 0)
        for draft in drafts where draft.include {
            guard !draft.ru.trimmed.isEmpty else {
                result.skippedWithoutTranslation += 1
                continue
            }
            let key = PolishText.dedupKey(draft.pl)
            guard !key.isEmpty, !seen.contains(key) else {
                result.skippedDuplicates += 1
                continue
            }
            seen.insert(key)
            result.cards.append(Flashcard(
                pl: draft.pl,
                ru: draft.ru,
                base: draft.base,
                form: draft.form,
                alternation: draft.alternation,
                note: draft.note,
                source: draft.source,
                photoId: draft.source == .photo ? photoId : nil,
                created: now
            ))
        }
        return result
    }
}
