import Foundation

/// A piece of a paragraph: a word (a run of letters, tappable) or anything between words.
struct ReaderToken: Identifiable, Hashable, Sendable {
    /// Unique across the whole document.
    let id: Int
    let paragraph: Int
    let text: String
    let isWord: Bool
    /// Index of the sentence within its paragraph.
    let sentence: Int
    let range: Range<String.Index>
}

struct ReaderParagraph: Identifiable, Sendable {
    let id: Int
    let text: String
    let tokens: [ReaderToken]
    /// Token index ranges (within `tokens`) of the sentences.
    let sentences: [Range<Int>]
}

/// A word or a phrase picked in the reader, with the sentence(s) around it.
struct ReaderSelection: Hashable, Sendable {
    let paragraph: Int
    let firstTokenID: Int
    let lastTokenID: Int
    /// Exactly as in the text, including inner punctuation.
    let text: String
    /// The sentence the selection belongs to (several, if a phrase crosses a sentence end).
    let sentence: String

    var tokenIDs: ClosedRange<Int> { firstTokenID...lastTokenID }
    var isPhrase: Bool { firstTokenID != lastTokenID }
}

/// Splits paragraphs into words and punctuation and finds sentence boundaries. Text is never
/// interpreted as markup: the reader builds plain attributed strings from these tokens.
struct ReaderDocument: Sendable {
    static let abbreviations: Set<String> = [
        "np", "tzn", "tj", "itd", "itp", "m.in", "in", "ul", "al", "pl", "os", "godz", "min", "dr", "prof",
        "mgr", "inż", "hab", "ok", "wg", "nr", "tel", "zob", "por", "r", "w", "ww", "jw", "św", "p", "s", "ds", "sp",
    ]

    let paragraphs: [ReaderParagraph]

    init(paragraphs texts: [String]) {
        var nextID = 0
        var paragraphs: [ReaderParagraph] = []
        for (paragraphIndex, rawText) in texts.enumerated() {
            let text = PolishText.nfc(rawText)
            let pieces = ReaderDocument.pieces(of: text).map { (text: String(text[$0.range]), isWord: $0.isWord, range: $0.range) }
            let sentenceRanges = ReaderDocument.sentenceRanges(pieces.map { ($0.text, $0.isWord) })
            var tokens: [ReaderToken] = []
            for (sentenceIndex, range) in sentenceRanges.enumerated() {
                for pieceIndex in range {
                    let piece = pieces[pieceIndex]
                    tokens.append(ReaderToken(
                        id: nextID, paragraph: paragraphIndex, text: piece.text, isWord: piece.isWord,
                        sentence: sentenceIndex, range: piece.range
                    ))
                    nextID += 1
                }
            }
            paragraphs.append(ReaderParagraph(id: paragraphIndex, text: text, tokens: tokens, sentences: sentenceRanges))
        }
        self.paragraphs = paragraphs
    }

    var wordCount: Int {
        paragraphs.reduce(0) { $0 + $1.tokens.filter(\.isWord).count }
    }

    func token(id: Int) -> ReaderToken? {
        for paragraph in paragraphs {
            guard let first = paragraph.tokens.first, let last = paragraph.tokens.last else { continue }
            if (first.id...last.id).contains(id) { return paragraph.tokens[id - first.id] }
        }
        return nil
    }

    /// A word, or a phrase from one word to another within a paragraph (in either order).
    func selection(from startID: Int, to endID: Int) -> ReaderSelection? {
        guard let a = token(id: min(startID, endID)), let b = token(id: max(startID, endID)),
              a.isWord, b.isWord, a.paragraph == b.paragraph
        else { return nil }
        let paragraph = paragraphs[a.paragraph]
        let firstSentence = paragraph.sentences[a.sentence]
        let lastSentence = paragraph.sentences[b.sentence]
        let sentenceStart = paragraph.tokens[firstSentence.lowerBound].range.lowerBound
        let sentenceEnd = paragraph.tokens[lastSentence.upperBound - 1].range.upperBound
        return ReaderSelection(
            paragraph: a.paragraph,
            firstTokenID: a.id,
            lastTokenID: b.id,
            text: String(paragraph.text[a.range.lowerBound..<b.range.upperBound]),
            sentence: String(paragraph.text[sentenceStart..<sentenceEnd]).trimmed
        )
    }

    /// Token ids of every occurrence of the phrases (case-insensitive, whole words).
    func occurrences(of phrases: [String]) -> Set<Int> {
        let patterns = phrases
            .map { PolishText.words(in: PolishText.nfc($0).lowercased()) }
            .filter { !$0.isEmpty }
        guard !patterns.isEmpty else { return [] }
        let byFirstWord = Dictionary(grouping: patterns, by: { $0[0] })
        var result = Set<Int>()
        for paragraph in paragraphs {
            let words = paragraph.tokens.filter(\.isWord)
            let lowered = words.map { $0.text.lowercased() }
            for start in words.indices {
                for pattern in byFirstWord[lowered[start]] ?? [] {
                    let end = start + pattern.count
                    guard end <= words.count, Array(lowered[start..<end]) == pattern else { continue }
                    // Mark the words and the gaps between them, so a phrase is highlighted as one piece.
                    result.formUnion(words[start].id...words[end - 1].id)
                }
            }
        }
        return result
    }

    /// Runs of letters (words) and the text between them. The text between words is cut once more
    /// where a space is followed by a mark, so that ". — " becomes ". " (end of a sentence) and
    /// "— " (start of the next one).
    static func pieces(of text: String) -> [(range: Range<String.Index>, isWord: Bool)] {
        var result: [(range: Range<String.Index>, isWord: Bool)] = []
        var index = text.startIndex
        while index < text.endIndex {
            let isWord = text[index].isLetter
            var end = text.index(after: index)
            while end < text.endIndex && text[end].isLetter == isWord { end = text.index(after: end) }
            if isWord {
                result.append((index..<end, true))
            } else {
                var segmentStart = index
                var sawSpace = false
                var cursor = index
                while cursor < end {
                    if text[cursor].isWhitespace {
                        sawSpace = true
                    } else if sawSpace {
                        result.append((segmentStart..<cursor, false))
                        segmentStart = cursor
                        sawSpace = false
                    }
                    cursor = text.index(after: cursor)
                }
                result.append((segmentStart..<end, false))
            }
            index = end
        }
        return result
    }

    /// Splits a paragraph's pieces into sentences. A sentence ends at . ! ? … unless the next word
    /// starts with a lower-case letter (dialogue tags, "rzeką… przy rzece") or the dot closes an abbreviation.
    static func sentenceRanges(_ pieces: [(text: String, isWord: Bool)]) -> [Range<Int>] {
        guard !pieces.isEmpty else { return [] }
        var ranges: [Range<Int>] = []
        var start = 0
        for index in pieces.indices where !pieces[index].isWord {
            let text = pieces[index].text
            guard text.contains(where: { ".!?…".contains($0) }) else { continue }
            if let next = pieces[(index + 1)...].first(where: { $0.isWord }), next.text.first?.isLowercase == true {
                continue
            }
            let onlyDots = !text.contains(where: { "!?…".contains($0) })
            if onlyDots, index > 0, pieces[index - 1].isWord {
                let previous = pieces[index - 1].text.lowercased()
                let isInitial = previous.count == 1 && pieces[index - 1].text.first?.isUppercase == true
                if abbreviations.contains(previous) || isInitial { continue }
            }
            ranges.append(start..<(index + 1))
            start = index + 1
        }
        if start < pieces.count { ranges.append(start..<pieces.count) }
        return ranges
    }
}
