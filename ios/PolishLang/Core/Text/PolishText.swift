import Foundation

/// Text helpers for Polish: normalization, folding of diacritics, slugs and stable hashes.
enum PolishText {
    /// Letters that the system keyboard of a Russian speaker usually lacks.
    static let diacriticLetters: [String] = ["ą", "ć", "ę", "ł", "ń", "ó", "ś", "ź", "ż"]

    private static let foldMap: [Character: Character] = [
        "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ź": "z", "ż": "z",
        "Ą": "A", "Ć": "C", "Ę": "E", "Ł": "L", "Ń": "N", "Ó": "O", "Ś": "S", "Ź": "Z", "Ż": "Z",
    ]

    /// Canonical composition, so that "ą" typed as a + combining ogonek equals the precomposed "ą".
    static func nfc(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
    }

    /// Replaces Polish letters with diacritics by their base letters: "książce" → "ksiazce".
    static func fold(_ text: String) -> String {
        String(nfc(text).map { foldMap[$0] ?? $0 })
    }

    /// Maximal runs of letters. The reader uses the same rule to make words tappable.
    static func words(in text: String) -> [String] {
        runs(in: text) { $0.isLetter }
    }

    static func wordCount(_ text: String) -> Int {
        words(in: text).count
    }

    /// Key that decides whether two cards hold the same form: lower case, no punctuation,
    /// single spaces. Diacritics are kept, so "rzeka" and "rzece" stay different cards.
    static func dedupKey(_ text: String) -> String {
        runs(in: nfc(text).lowercased()) { $0.isLetter || $0.isNumber }.joined(separator: " ")
    }

    static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0400...0x052F).contains($0.value) }
    }

    /// ASCII slug for identifiers: "przy rzece" → "przy-rzece".
    static func slug(_ text: String, maxLength: Int = 40) -> String {
        var out = ""
        for character in fold(text).lowercased() {
            if out.count >= maxLength { break }
            if character.isASCII && (character.isLetter || character.isNumber) {
                out.append(character)
            } else if !out.isEmpty && !out.hasSuffix("-") {
                out.append("-")
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }

    /// FNV-1a, 32 bits, as 8 hex digits. Unlike `hashValue` it is the same on every launch.
    static func stableHash(_ text: String) -> String {
        var hash: UInt32 = 2_166_136_261
        for byte in nfc(text).utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 8 - hex.count) + hex
    }

    private static func runs(in text: String, where belongs: (Character) -> Bool) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            if belongs(character) {
                current.append(character)
            } else if !current.isEmpty {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trims and replaces any run of whitespace (including line breaks) with one space.
    var collapsingWhitespace: String {
        split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
