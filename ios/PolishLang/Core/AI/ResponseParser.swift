import Foundation

/// A form to translate and, if the learner gave it, her base form.
struct EnrichInput: Hashable, Sendable {
    var pl: String
    var base: String = ""
}

/// One element of the TZ 1, 4.1 reply.
struct EnrichResult: Hashable, Sendable {
    var ru = ""
    var base = ""
    var baseCheck = ""
    var form = ""
    var alternation = ""
    var note = ""
    var fix = ""
    var isPolish = true
}

/// One element of the TZ 1, 4.2 reply.
struct PhotoItem: Hashable, Sendable {
    var pl: String
    var ru: String
    var base: String
    var lowConfidence: Bool
}

/// The TZ 2, 4.1 reply.
struct GeneratedText: Hashable, Sendable {
    var title: String
    var paragraphs: [String]
    var keyWords: [KeyWord]
    var usedMyWords: [String]
}

/// The TZ 2, 4.2 reply.
struct WordTranslation: Hashable, Sendable {
    var ru: String
    var base: String
    var pos: String
    var form: String
    var alternation: String
    var note: String
    var sentenceRu: String
}

enum ResponseParser {
    /// Elements in the same order as the input; `nil` where the reply has no element (TZ 1, 7: "нет перевода").
    static func enrichResults(from text: String, count: Int) throws -> [EnrichResult?] {
        guard let json = TolerantJSON.parse(text), let elements = items(in: json) else { throw AIError.invalidResponse }
        var results: [EnrichResult?] = elements.prefix(count).map { element in
            guard element.objectValue != nil else { return nil }
            return EnrichResult(
                ru: string(element["ru"]),
                base: string(element["base"]),
                baseCheck: string(element["baseCheck"]),
                form: string(element["form"]),
                alternation: string(element["alternation"]),
                note: string(element["note"]),
                fix: string(element["fix"]),
                isPolish: element["isPolish"]?.boolValue ?? true
            )
        }
        while results.count < count { results.append(nil) }
        return results
    }

    static func photoItems(from text: String) throws -> [PhotoItem] {
        guard let json = TolerantJSON.parse(text), let elements = items(in: json) else { throw AIError.invalidResponse }
        var seen = Set<String>()
        return elements.compactMap { element -> PhotoItem? in
            let pl = string(element["pl"])
            let key = PolishText.dedupKey(pl)
            guard !pl.isEmpty, !seen.contains(key) else { return nil }
            seen.insert(key)
            return PhotoItem(
                pl: pl,
                ru: string(element["ru"]),
                base: string(element["base"]),
                lowConfidence: string(element["confidence"]).lowercased() == "low" || pl.contains("[?]")
            )
        }
    }

    static func generatedText(from text: String) throws -> GeneratedText {
        guard let json = TolerantJSON.parse(text), json.objectValue != nil else { throw AIError.invalidResponse }
        let paragraphs = (json["paragraphs"]?.arrayValue ?? [])
            .map { string($0) }
            .filter { !$0.isEmpty }
        // An empty text is how a polite refusal inside valid JSON looks.
        guard !paragraphs.isEmpty else { throw AIError.refusal }
        let keyWords = (json["keyWords"]?.arrayValue ?? []).compactMap { element -> KeyWord? in
            let form = string(element["form"])
            guard !form.isEmpty else { return nil }
            return KeyWord(form: form, base: string(element["base"]), ru: string(element["ru"]))
        }
        let used = (json["usedMyWords"]?.arrayValue ?? []).map { string($0) }.filter { !$0.isEmpty }
        return GeneratedText(title: string(json["title"]), paragraphs: paragraphs, keyWords: keyWords, usedMyWords: used)
    }

    static func translation(from text: String) throws -> WordTranslation {
        guard let json = TolerantJSON.parse(text), json.objectValue != nil else { throw AIError.invalidResponse }
        let ru = string(json["ru"])
        guard !ru.isEmpty else { throw AIError.invalidResponse }
        return WordTranslation(
            ru: ru,
            base: string(json["base"]),
            pos: string(json["pos"]),
            form: string(json["form"]),
            alternation: string(json["alternation"]),
            note: string(json["note"]),
            sentenceRu: string(json["sentence_ru"] ?? json["sentenceRu"])
        )
    }

    /// The array inside a reply: the root itself, its "items", or the only array field.
    static func items(in json: JSONValue) -> [JSONValue]? {
        if let array = json.arrayValue { return array }
        if let items = json["items"]?.arrayValue { return items }
        let arrays = (json.objectValue ?? [:]).values.compactMap { $0.arrayValue }
        return arrays.count == 1 ? arrays[0] : nil
    }

    private static func string(_ value: JSONValue?) -> String {
        value?.stringValue?.trimmed ?? ""
    }
}
