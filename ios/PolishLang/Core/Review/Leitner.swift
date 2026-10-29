import Foundation

enum ReviewGrade: Sendable {
    /// Correct without hints: the card moves to the next box.
    case good
    /// "Almost", or correct after a hint: the card moves one box back (but not below 1).
    case hard
    /// Wrong or revealed: back to box 0, due again right away.
    case again
}

/// Leitner boxes for spaced repetition.
enum Leitner {
    /// Days until the next review, per box.
    static let intervals: [Double] = [0, 1, 2, 4, 8, 16, 32]
    static var maxBox: Int { intervals.count - 1 }

    static func grade(verdict: AnswerVerdict, usedHint: Bool, revealed: Bool) -> ReviewGrade {
        if revealed { return .again }
        switch verdict {
        case .correct: return usedHint ? .hard : .good
        case .almost: return .hard
        case .wrong: return .again
        }
    }

    static func apply(_ grade: ReviewGrade, mistake: Bool, to card: inout Flashcard, now: Date) {
        switch grade {
        case .good: card.box = min(card.box + 1, maxBox)
        case .hard: card.box = max(1, card.box - 1)
        case .again: card.box = 0
        }
        card.due = now.addingTimeInterval(intervals[card.box] * 86_400)
        if mistake {
            card.wrong += 1
        } else {
            card.right += 1
        }
    }
}

/// Picks the cards for a session.
enum StudyPlanner {
    static func dueCards(_ cards: [Flashcard], now: Date, limit: Int) -> [Flashcard] {
        Array(cards
            .filter { $0.due <= now }
            .sorted { ($0.due, $0.box) < ($1.due, $1.box) }
            .prefix(limit))
    }

    static func nextDueDate(_ cards: [Flashcard], now: Date) -> Date? {
        cards.map(\.due).filter { $0 > now }.min()
    }

    /// When nothing is due: weak cards first, then a random sample of the rest.
    static func practiceCards<G: RandomNumberGenerator>(_ cards: [Flashcard], limit: Int, using generator: inout G) -> [Flashcard] {
        let weak = cards.filter { $0.wrong > $0.right }.shuffled(using: &generator)
        let rest = cards.filter { $0.wrong <= $0.right }.shuffled(using: &generator)
        return Array((weak + rest).prefix(limit))
    }
}

/// Order of cards within one session. A missed card comes back a few cards later, at most twice.
struct StudyQueue: Sendable {
    static let maxRepeats = 2
    static let repeatGap = 3

    private(set) var pending: [String]
    private(set) var repeats: [String: Int] = [:]
    private(set) var finished: Int = 0

    init(cardIDs: [String]) {
        pending = cardIDs
    }

    var current: String? { pending.first }
    var isEmpty: Bool { pending.isEmpty }
    var remaining: Int { pending.count }

    mutating func advance(repeatCard: Bool) {
        guard !pending.isEmpty else { return }
        let id = pending.removeFirst()
        let count = repeats[id, default: 0]
        if repeatCard && count < StudyQueue.maxRepeats {
            repeats[id] = count + 1
            pending.insert(id, at: min(StudyQueue.repeatGap, pending.count))
        } else {
            finished += 1
        }
    }
}
