import Foundation

/// Checks of a generated text (TZ 2, section 4.1).
struct GenerationCheck: Sendable {
    var wordCount: Int
    /// Soft warning when the length is off the level profile by more than 20%.
    var lengthWarning: String?
    /// Cyrillic in the Polish text: the reply is not usable, offer "Ещё раз".
    var hasCyrillic: Bool
    /// Key words whose form really occurs in the text.
    var keyWords: [KeyWord]
    /// The learner's words that really occur in the text.
    var usedMyWords: [String]
}

enum GenerationValidator {
    static let tolerance = 0.2

    static func check(_ text: GeneratedText, level: CEFRLevel) -> GenerationCheck {
        let document = ReaderDocument(paragraphs: text.paragraphs)
        let count = document.wordCount
        let range = level.wordRange
        let lower = Int((Double(range.lowerBound) * (1 - tolerance)).rounded(.down))
        let upper = Int((Double(range.upperBound) * (1 + tolerance)).rounded(.up))
        var warning: String?
        if count < lower || count > upper {
            let direction = count < lower ? "короче" : "длиннее"
            warning = "Текст \(direction) нормы \(level.rawValue): \(count) слов при норме \(range.lowerBound)–\(range.upperBound)."
        }
        let hasCyrillic = PolishText.containsCyrillic(text.title) || text.paragraphs.contains(where: PolishText.containsCyrillic)
        let keyWords = text.keyWords.filter { !document.occurrences(of: [$0.form]).isEmpty }
        let used = text.usedMyWords.filter { !document.occurrences(of: [$0]).isEmpty }
        return GenerationCheck(wordCount: count, lengthWarning: warning, hasCyrillic: hasCyrillic, keyWords: keyWords, usedMyWords: used)
    }
}

/// Chooses the learner's words to weave into a text: recent cards and cards with mistakes first (TZ 2, section 2).
enum MyWordsPicker {
    static let limit = 8
    static let recentDays: Double = 14

    static func pick<G: RandomNumberGenerator>(
        from cards: [Flashcard],
        mistakeCardIDs: Set<String>,
        now: Date,
        limit: Int = MyWordsPicker.limit,
        using generator: inout G
    ) -> [String] {
        let usable = cards.filter { card in
            let words = PolishText.words(in: card.pl)
            return !words.isEmpty && words.count <= 3 && !card.pl.contains("[?]")
        }
        func score(_ card: Flashcard) -> Double {
            var score = 0.0
            if card.wrong > 0 || mistakeCardIDs.contains(card.id) { score += 2 }
            let ageDays = now.timeIntervalSince(card.created) / 86_400
            if ageDays < recentDays { score += 1 + (recentDays - ageDays) / recentDays }
            return score
        }
        // A little noise gives variety between texts without overriding the priorities.
        let ranked = usable
            .map { (card: $0, score: score($0) + Double.random(in: 0..<0.75, using: &generator)) }
            .sorted { $0.score > $1.score }
            .map(\.card)
        var seen = Set<String>()
        var words: [String] = []
        for card in ranked {
            let word = card.base.isEmpty ? card.pl : card.base
            let key = PolishText.dedupKey(word)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            words.append(word)
            if words.count == limit { break }
        }
        return words
    }
}
