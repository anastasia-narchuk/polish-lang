import Foundation

/// An entry of the mistake bank: what was expected, what was typed and which kind of mistake it was.
struct Mistake: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var cardId: String
    var expected: String
    var given: String
    var verdict: AnswerVerdict
    var types: [SpellingErrorType]
    var date: Date

    init(cardId: String, check: AnswerCheck, date: Date = Date()) {
        self.id = UUID().uuidString
        self.cardId = cardId
        self.expected = check.expected
        self.given = check.given
        self.verdict = check.verdict
        self.types = check.errorTypes.isEmpty ? [.other] : check.errorTypes
        self.date = date
    }
}
