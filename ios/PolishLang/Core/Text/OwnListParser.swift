import Foundation

/// A line of the learner's own list: the form, optionally `[base]` and a translation.
struct ParsedEntry: Equatable, Sendable {
    var pl: String
    var base: String = ""
    var ru: String = ""
}

/// Parses a word list typed or pasted by the learner (TZ 1, section 2.2):
///
///     rzece
///     rzece — реке
///     rzece [rzeka]
///     rzece [rzeka] — реке
///     morzu, przy rzece, poszłam      (a single line without a dash: split by commas)
///
/// The separator is a dash with spaces around it (em/en dash need a space on one side only)
/// or a tab. Otherwise commas stay part of the phrase.
enum OwnListParser {
    static func parse(_ input: String) -> [ParsedEntry] {
        let lines = input
            .components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        if lines.count == 1, lines[0].contains(","), separatorRange(in: lines[0]) == nil {
            return splitOutsideBrackets(lines[0], by: ",").compactMap { parseLine($0) }
        }
        return lines.compactMap { parseLine($0) }
    }

    static func parseLine(_ rawLine: String) -> ParsedEntry? {
        let line = stripListMarker(rawLine.trimmed)
        var left = line
        var ru = ""
        if let separator = separatorRange(in: line) {
            left = String(line[..<separator.lowerBound])
            ru = String(line[separator.upperBound...]).trimmed
        }
        var base = ""
        if let open = left.firstIndex(of: "["), let close = left[open...].firstIndex(of: "]") {
            base = String(left[left.index(after: open)..<close]).collapsingWhitespace
            left.removeSubrange(open...close)
        }
        let pl = PolishText.nfc(left.collapsingWhitespace)
        guard !pl.isEmpty else { return nil }
        return ParsedEntry(pl: pl, base: PolishText.nfc(base), ru: ru.collapsingWhitespace)
    }

    /// Range of the form/translation separator: a tab, " - ", or "—"/"–" next to a space.
    static func separatorRange(in line: String) -> Range<String.Index>? {
        let characters = Array(line.indices)
        for (offset, index) in characters.enumerated() {
            let character = line[index]
            if character == "\t" {
                return index..<line.index(after: index)
            }
            guard character == "—" || character == "–" || character == "-" else { continue }
            let spaceBefore = offset > 0 && line[characters[offset - 1]].isWhitespace
            let spaceAfter = offset + 1 < characters.count && line[characters[offset + 1]].isWhitespace
            let isSeparator = character == "-" ? (spaceBefore && spaceAfter) : (spaceBefore || spaceAfter)
            if isSeparator && offset > 0 {
                return index..<line.index(after: index)
            }
        }
        return nil
    }

    /// "1. rzece", "2) rzece", "- rzece", "• rzece" → "rzece".
    static func stripListMarker(_ line: String) -> String {
        var rest = Substring(line)
        if let first = rest.first, "•*-–—".contains(first), rest.dropFirst().first?.isWhitespace == true {
            rest = rest.dropFirst()
        } else {
            let digits = rest.prefix(while: { $0.isNumber })
            let afterDigits = rest.dropFirst(digits.count)
            if !digits.isEmpty, let mark = afterDigits.first, mark == "." || mark == ")",
               afterDigits.dropFirst().first?.isWhitespace == true {
                rest = afterDigits.dropFirst()
            }
        }
        return String(rest).trimmed
    }

    private static func splitOutsideBrackets(_ line: String, by delimiter: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for character in line {
            if character == "[" { depth += 1 }
            if character == "]" { depth = max(0, depth - 1) }
            if character == delimiter && depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts.map { $0.trimmed }.filter { !$0.isEmpty }
    }
}
