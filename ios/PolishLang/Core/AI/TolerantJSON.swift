import Foundation

/// Reads JSON out of a model reply: the whole text, a ```json block, or the span from the
/// first `[`/`{` to the last `]`/`}` (TZ 1, section 4).
enum TolerantJSON {
    static func parse(_ text: String) -> JSONValue? {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return nil }
        if let value = JSONValue.decode(Data(trimmed.utf8)) { return value }
        if let block = fencedBlock(in: trimmed), let value = JSONValue.decode(Data(block.utf8)) { return value }
        if let span = outerSpan(of: trimmed), let value = JSONValue.decode(Data(span.utf8)) { return value }
        return nil
    }

    /// Content of the first ``` fence, without the language tag.
    static func fencedBlock(in text: String) -> String? {
        guard let open = text.range(of: "```") else { return nil }
        var rest = text[open.upperBound...]
        if let newline = rest.firstIndex(of: "\n") {
            let tag = rest[..<newline].trimmingCharacters(in: .whitespaces)
            if tag.isEmpty || tag.allSatisfy({ $0.isLetter }) {
                rest = rest[rest.index(after: newline)...]
            }
        }
        guard let close = rest.range(of: "```") else { return nil }
        return String(rest[..<close.lowerBound]).trimmed
    }

    static func outerSpan(of text: String) -> String? {
        guard let start = text.firstIndex(where: { $0 == "[" || $0 == "{" }),
              let end = text.lastIndex(where: { $0 == "]" || $0 == "}" }),
              start < end
        else { return nil }
        return String(text[start...end])
    }
}
