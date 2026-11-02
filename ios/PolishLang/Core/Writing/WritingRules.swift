import Foundation

/// How visible a part of the support is on a step (TZ 3, section 5).
enum SupportVisibility: Equatable, Sendable {
    case open
    /// Hidden; opening it marks the text "с опорой".
    case hidden
    case unavailable
}

/// The visibility table of section 5 for one task.
struct SupportPolicy: Equatable, Sendable {
    enum Timer: Equatable, Sendable {
        case none, stopwatch, countdown
    }

    var plan: SupportVisibility
    var connectors: SupportVisibility
    var ideas: SupportVisibility
    var traps: SupportVisibility
    var translationAvailable: Bool
    var lettersBar: Bool
    var timer: Timer

    /// Akapit and "Свой текст" keep the support open; exam training hides it; the simulation
    /// (stage 3) takes everything away. The letters bar is only for typing on Akapit.
    static func of(mode: WritingMode, hand: Bool, simulation: Bool = false) -> SupportPolicy {
        if simulation {
            return SupportPolicy(plan: .unavailable, connectors: .unavailable, ideas: .unavailable, traps: .unavailable,
                                 translationAvailable: false, lettersBar: false, timer: .countdown)
        }
        switch mode {
        case .akapit, .own:
            return SupportPolicy(plan: .open, connectors: .open, ideas: .open, traps: .open,
                                 translationAvailable: true, lettersBar: !hand, timer: .none)
        case .exam:
            return SupportPolicy(plan: .hidden, connectors: .hidden, ideas: .hidden, traps: .open,
                                 translationAvailable: true, lettersBar: false, timer: .stopwatch)
        }
    }

    /// The panel starts open when its main parts are open.
    var startsOpen: Bool {
        plan == .open
    }
}

/// Word count against the target: green in range, yellow up to 20% off, red beyond (TZ 3, 4.2).
enum LengthStatus: Equatable, Sendable {
    case ok, near, far
}

enum WritingRules {
    static let akapitRange = 50...80
    /// Fewer words and the check buttons stay off (TZ 3, section 12).
    static let minimumWords = 5

    static func range(for task: WritingTask, mode: WritingMode) -> ClosedRange<Int> {
        if mode == .akapit { return akapitRange }
        let target = max(10, task.words)
        let low = Int((Double(target) * 0.9).rounded())
        let high = Int((Double(target) * 1.1).rounded())
        return low...max(low, high)
    }

    static func lengthStatus(count: Int, range: ClosedRange<Int>) -> LengthStatus {
        if range.contains(count) { return .ok }
        let lower = Double(range.lowerBound) * 0.8
        let upper = Double(range.upperBound) * 1.2
        return Double(count) >= lower && Double(count) <= upper ? .near : .far
    }

    // MARK: Required words

    /// The stem a chip is matched by: a word of up to 3 letters as is, otherwise without its last two letters.
    static func stem(_ word: String) -> String {
        let lowered = PolishText.nfc(word).lowercased()
        guard lowered.count > 3 else { return lowered }
        return String(lowered.prefix(max(3, lowered.count - 2)))
    }

    /// The word or phrase occurs in the text in any form: every word of it, in a row, starts with its stem.
    static func isUsed(_ phrase: String, in text: String) -> Bool {
        let stems = PolishText.words(in: phrase).map(stem)
        guard !stems.isEmpty else { return false }
        let words = PolishText.words(in: PolishText.nfc(text).lowercased())
        guard words.count >= stems.count else { return false }
        for start in 0...(words.count - stems.count) {
            if zip(words[start..<(start + stems.count)], stems).allSatisfy({ $0.hasPrefix($1) }) { return true }
        }
        return false
    }

    // MARK: Scoring

    /// Guards on top of the model's verdict, so the grade stays exam-like (TZ 3, criteria 4 and 5):
    /// a missed point caps "zadanie" at 3, and mixed salutations make the register inconsistent.
    static func applyGuards(_ check: TextCheck, text: String) -> TextCheck {
        var check = check
        if check.points.contains(where: { $0.status == .no }) {
            check.scores.zadanie = min(check.scores.zadanie, 3)
        }
        if let issue = RegisterHeuristics.mixingIssue(in: text) {
            check.register.consistent = false
            if !check.register.issuesRu.contains(where: { $0.localizedCaseInsensitiveContains("смеш") }) {
                check.register.issuesRu.append(issue)
            }
        }
        return check
    }

    /// Points of an exam task out of its weight (10 or 20 by the settings).
    static func taskPoints(percent: Int, weight: Int) -> Int {
        Int((Double(percent) / 100 * Double(weight)).rounded())
    }

    // MARK: The ladder

    struct StepProgress: Equatable, Sendable {
        var good: Int
        var hand: Int
        var met: Bool
        var fraction: Double
        var text: String
    }

    /// Akapit → Egzamin: 3 paragraphs with at least 70%, 2 of them handwritten (rule of the artifact).
    static func akapitProgress(_ texts: [WritingText]) -> StepProgress {
        let good = texts.filter { $0.mode == .akapit && $0.score >= 70 }
        let hand = good.filter(\.hand).count
        let met = good.count >= 3 && hand >= 2
        let fraction = Double(min(good.count, 3) + min(hand, 2)) / 5
        return StepProgress(good: good.count, hand: hand, met: met, fraction: fraction,
                            text: "\(min(good.count, 3)) из 3 абзацев на 70% и выше, от руки — \(min(hand, 2)) из 2")
    }

    /// Readiness forecast out of 30: the last 3 exam texts written by hand without support (TZ 3, section 9).
    static func forecast(_ texts: [WritingText]) -> Int? {
        let eligible = texts.filter { $0.mode == .exam && $0.hand && !$0.support.opened }.prefix(3)
        guard eligible.count == 3 else { return nil }
        let average = Double(eligible.map(\.score).reduce(0, +)) / 3
        return Int((average / 100 * 30).rounded())
    }

    // MARK: Errors in the text

    /// Where each error's fragment is in the text: in order of the list, the next occurrence after
    /// the previous one, otherwise anywhere; overlapping fragments are skipped. Errors whose
    /// fragment is not in the text get no range (TZ 3, section 12).
    static func errorRanges(in text: String, errors: [TextError]) -> [Int: Range<String.Index>] {
        var result: [Int: Range<String.Index>] = [:]
        var taken: [Range<String.Index>] = []
        var cursor = text.startIndex
        for (index, error) in errors.enumerated() {
            let fragment = error.fragment
            guard !fragment.isEmpty else { continue }
            let found = text.range(of: fragment, range: cursor..<text.endIndex) ?? text.range(of: fragment)
            guard let range = found, !taken.contains(where: { $0.overlaps(range) }) else { continue }
            result[index] = range
            taken.append(range)
            if range.lowerBound >= cursor { cursor = range.upperBound }
        }
        return result
    }

    /// Spelling subcategory of a mistake for the bank: ó/u, rz/ż, ch/h, ą/ę, nie, ogonki.
    static func spellingCategory(fragment: String, correction: String) -> String? {
        let given = AnswerChecker.normalize(fragment)
        let expected = AnswerChecker.normalize(correction)
        guard given != expected else { return nil }
        let joinedGiven = given.replacingOccurrences(of: " ", with: "")
        let joinedExpected = expected.replacingOccurrences(of: " ", with: "")
        if joinedGiven == joinedExpected, (given + expected).contains("nie") { return "nie" }
        let types = AnswerChecker.classify(given: given, expected: expected).filter { $0 != .other && $0 != .ending }
        return types.first?.rawValue
    }
}

/// Mixed salutations in one text: "Szanowny Panie" together with "jak się masz?" (TZ 3, criterion 5).
enum RegisterHeuristics {
    static let formal = ["szanowny", "szanowna", "szanowni", "szanownego", "szanownej", "z poważaniem", "z wyrazami szacunku", "łączę wyrazy szacunku"]
    static let informal = ["cześć", "hej", "jak się masz", "co u ciebie", "trzymaj się", "buziaki", "całuję", "ściskam"]

    static func markers(_ list: [String], in text: String) -> [String] {
        list.filter { WritingRules.containsPhrase($0, in: text) }
    }

    /// A Russian note when formal and informal formulas meet in one text.
    static func mixingIssue(in text: String) -> String? {
        guard let formal = markers(formal, in: text).first, let informal = markers(informal, in: text).first else { return nil }
        return "В одном тексте смешаны официальное «\(formal)» и разговорное «\(informal)». Выбери один регистр: в официальном письме — Pan/Pani и формулы вроде «Z poważaniem», в личном — ty и «Pozdrawiam»."
    }
}

extension WritingRules {
    /// Whole words in a row, case-insensitive.
    static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let pattern = PolishText.words(in: PolishText.nfc(phrase).lowercased())
        let words = PolishText.words(in: PolishText.nfc(text).lowercased())
        guard !pattern.isEmpty, words.count >= pattern.count else { return false }
        for start in 0...(words.count - pattern.count) where Array(words[start..<(start + pattern.count)]) == pattern {
            return true
        }
        return false
    }
}
