import Foundation

enum AnswerVerdict: String, Codable, Sendable {
    case correct, almost, wrong
}

/// Kinds of spelling mistakes kept in the mistake bank (TZ 1, section 6).
enum SpellingErrorType: String, Codable, CaseIterable, Identifiable, Sendable {
    case uO = "ó/u"
    case rzZ = "rz/ż"
    case chH = "ch/h"
    case nasal = "ą/ę"
    case ogonki = "ogonki"
    case ending = "ending"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uO: return "ó / u"
        case .rzZ: return "rz / ż"
        case .chH: return "ch / h"
        case .nasal: return "ą / ę"
        case .ogonki: return "ogonki"
        case .ending: return "окончание"
        case .other: return "другое"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SpellingErrorType(rawValue: raw) ?? .other
    }
}

/// One step of the letter-by-letter alignment of the answer with the expected form.
enum DiffOp: Equatable, Sendable {
    case same(Character)
    case substitute(expected: Character, given: Character)
    /// A letter of the expected form that was not typed.
    case missing(Character)
    /// A typed letter that is not in the expected form.
    case extra(Character)

    var isSame: Bool {
        if case .same = self { return true }
        return false
    }
}

struct AnswerCheck: Equatable, Sendable {
    var verdict: AnswerVerdict
    /// Normalized expected form and answer.
    var expected: String
    var given: String
    var diff: [DiffOp]
    var errorTypes: [SpellingErrorType]
}

/// Strict comparison with diacritics. Differences only in ogonki, or one letter in a long word,
/// count as "almost" (TZ 1, section 6).
enum AnswerChecker {
    /// A word this long with one wrong letter counts as "almost".
    static let longWordLength = 7

    static func normalize(_ text: String) -> String {
        PolishText.nfc(text).lowercased().collapsingWhitespace
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
    }

    static func check(given rawGiven: String, expected rawExpected: String) -> AnswerCheck {
        let given = normalize(rawGiven)
        let expected = normalize(rawExpected)
        let diff = alignment(expected: Array(expected), given: Array(given))
        guard given != expected else {
            return AnswerCheck(verdict: .correct, expected: expected, given: given, diff: diff, errorTypes: [])
        }
        let distance = diff.filter { !$0.isSame }.count
        let onlyDiacritics = PolishText.fold(given) == PolishText.fold(expected)
        let oneLetterInLongWord = distance == 1 && expected.count >= longWordLength
        let verdict: AnswerVerdict = !given.isEmpty && (onlyDiacritics || oneLetterInLongWord) ? .almost : .wrong
        return AnswerCheck(
            verdict: verdict, expected: expected, given: given, diff: diff,
            errorTypes: classify(given: given, expected: expected)
        )
    }

    /// Levenshtein alignment, expected letters first.
    static func alignment(expected: [Character], given: [Character]) -> [DiffOp] {
        let n = expected.count
        let m = given.count
        var cost = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { cost[i][0] = i }
        for j in 0...m { cost[0][j] = j }
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let substitution = cost[i - 1][j - 1] + (expected[i - 1] == given[j - 1] ? 0 : 1)
                    cost[i][j] = min(cost[i - 1][j] + 1, cost[i][j - 1] + 1, substitution)
                }
            }
        }
        var ops: [DiffOp] = []
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && cost[i][j] == cost[i - 1][j - 1] + (expected[i - 1] == given[j - 1] ? 0 : 1) {
                ops.append(expected[i - 1] == given[j - 1]
                    ? .same(expected[i - 1])
                    : .substitute(expected: expected[i - 1], given: given[j - 1]))
                i -= 1
                j -= 1
            } else if i > 0 && cost[i][j] == cost[i - 1][j] + 1 {
                ops.append(.missing(expected[i - 1]))
                i -= 1
            } else {
                ops.append(.extra(given[j - 1]))
                j -= 1
            }
        }
        return ops.reversed()
    }

    /// Which typical confusions explain the difference between the answer and the expected form.
    static func classify(given: String, expected: String) -> [SpellingErrorType] {
        guard given != expected else { return [] }
        guard !given.isEmpty else { return [.other] }
        let transforms: [(type: SpellingErrorType, apply: (String) -> String)] = [
            (.uO, { $0.replacingOccurrences(of: "ó", with: "u") }),
            (.rzZ, { $0.replacingOccurrences(of: "rz", with: "ż") }),
            (.chH, { $0.replacingOccurrences(of: "ch", with: "h") }),
            (.nasal, { $0.replacingOccurrences(of: "ą", with: "ę") }),
            (.ogonki, { PolishText.fold($0) }),
        ]
        if let single = transforms.first(where: { $0.apply(given) == $0.apply(expected) }) {
            return [single.type]
        }
        for (index, first) in transforms.enumerated() {
            for second in transforms[(index + 1)...] {
                if second.apply(first.apply(given)) == second.apply(first.apply(expected)) {
                    return [first.type, second.type]
                }
            }
        }
        return differsOnlyInEnding(given: given, expected: expected) ? [.ending] : [.other]
    }

    /// Same beginning (at least 3 letters), and at most 3 letters differ at the end.
    static func differsOnlyInEnding(given: String, expected: String) -> Bool {
        let g = Array(given)
        let e = Array(expected)
        var prefix = 0
        while prefix < min(g.count, e.count) && g[prefix] == e[prefix] { prefix += 1 }
        return prefix >= 3 && e.count - prefix <= 3 && g.count - prefix <= 3
    }
}
