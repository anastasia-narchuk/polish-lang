import Foundation
import Observation

/// One review session (TZ 1, section 6): the answer is typed, compared strictly with diacritics,
/// and after it the base form and the alternation are shown.
@MainActor
@Observable
final class StudyModel: Identifiable {
    enum Stage: Equatable {
        case answering, checked
    }

    let id = UUID()
    let total: Int
    var answer = ""
    private(set) var queue: StudyQueue
    private(set) var stage: Stage = .answering
    private(set) var hintLevel = 0
    private(set) var check: AnswerCheck?
    private(set) var revealed = false
    private(set) var lastGrade: ReviewGrade?
    private(set) var verdicts: [AnswerVerdict] = []
    @ObservationIgnored private var cards: [String: Flashcard]

    init(cards: [Flashcard]) {
        self.cards = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.queue = StudyQueue(cardIDs: cards.map(\.id))
        self.total = cards.count
    }

    var current: Flashcard? {
        queue.current.flatMap { cards[$0] }
    }

    var isFinished: Bool {
        queue.isEmpty
    }

    var progress: Double {
        total == 0 ? 1 : Double(queue.finished) / Double(total)
    }

    // MARK: Hints: the base form first (if the card has one), then the first letters.

    private var hintSteps: Int {
        guard let card = current else { return 0 }
        return card.base.isEmpty ? 1 : 2
    }

    var canHint: Bool {
        stage == .answering && hintLevel < hintSteps
    }

    var baseHint: String? {
        guard let card = current, !card.base.isEmpty, hintLevel >= 1 else { return nil }
        return card.base
    }

    var lettersHint: String? {
        guard let card = current, hintLevel >= hintSteps, hintLevel > 0 else { return nil }
        let letters = max(1, card.pl.count / 3)
        return String(card.pl.prefix(letters)) + "…"
    }

    func nextHint() {
        if canHint { hintLevel += 1 }
    }

    // MARK: Answer

    /// Checks the answer and updates the card's box. Returns the updated card and the mistake
    /// to keep in the mistake bank, if there is one.
    func submit(reveal: Bool = false, now: Date = Date()) -> (card: Flashcard, mistake: Mistake?)? {
        guard stage == .answering, var card = current else { return nil }
        let result = AnswerChecker.check(given: answer, expected: card.pl)
        let grade = Leitner.grade(verdict: result.verdict, usedHint: hintLevel > 0, revealed: reveal)
        Leitner.apply(grade, mistake: reveal || result.verdict != .correct, to: &card, now: now)
        cards[card.id] = card
        check = result
        revealed = reveal
        lastGrade = grade
        stage = .checked
        verdicts.append(reveal ? .wrong : result.verdict)
        let mistake = result.verdict != .correct && !result.given.isEmpty ? Mistake(cardId: card.id, check: result, date: now) : nil
        return (card, mistake)
    }

    func next() {
        guard stage == .checked else { return }
        queue.advance(repeatCard: lastGrade == .again)
        answer = ""
        hintLevel = 0
        check = nil
        revealed = false
        lastGrade = nil
        stage = .answering
    }

    var summary: (correct: Int, almost: Int, wrong: Int) {
        (
            verdicts.filter { $0 == .correct }.count,
            verdicts.filter { $0 == .almost }.count,
            verdicts.filter { $0 == .wrong }.count
        )
    }
}
