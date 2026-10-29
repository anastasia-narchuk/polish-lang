import Foundation

enum Russian {
    /// "1 слово", "3 слова", "11 слов".
    static func plural(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        let word: String
        if (11...14).contains(mod100) {
            word = many
        } else if mod10 == 1 {
            word = one
        } else if (2...4).contains(mod10) {
            word = few
        } else {
            word = many
        }
        return "\(count) \(word)"
    }

    static func words(_ count: Int) -> String {
        plural(count, "слово", "слова", "слов")
    }
}

extension CEFRLevel {
    /// What the level means, in a line under the level picker.
    var summary: String {
        let length = "\(wordRange.lowerBound)–\(wordRange.upperBound) слов"
        switch self {
        case .a1: return "\(length) · короткие простые предложения, только настоящее время"
        case .a2: return "\(length) · прошедшее и будущее время, связки i, ale, więc, bo"
        case .b1: return "\(length) · сложноподчинённые предложения, мнения, условное наклонение"
        case .b2: return "\(length) · пассив, причастия, публицистика и идиомы"
        }
    }
}
