import Foundation

enum CardSource: String, Codable, CaseIterable, Sendable {
    case manual, list, photo, text

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CardSource(rawValue: raw) ?? .manual
    }

    var title: String {
        switch self {
        case .manual: return "вручную"
        case .list: return "списком"
        case .photo: return "с фото"
        case .text: return "из текста"
        }
    }
}

/// A card keeps the form exactly as the learner met it ("rzece", not "rzeka"); the translation
/// conveys that form, and `base` / `alternation` explain it after the answer (TZ 1, section 5).
struct Flashcard: Identifiable, Codable, Hashable, Sendable {
    static let defaultTopic = "moje"

    var id: String
    var pl: String
    var ru: String
    /// Base (dictionary) form, "" when it equals `pl`.
    var base: String
    var form: String
    var alternation: String
    var note: String
    var topic: String
    var source: CardSource
    var photoId: String?
    var created: Date
    // Spaced repetition (Leitner boxes).
    var box: Int
    var due: Date
    var right: Int
    var wrong: Int
    // Cards added from the reader keep the sentence they came from.
    var example: String?
    var exampleRu: String?
    var textId: String?

    init(
        pl: String,
        ru: String,
        base: String = "",
        form: String = "",
        alternation: String = "",
        note: String = "",
        topic: String = Flashcard.defaultTopic,
        source: CardSource,
        photoId: String? = nil,
        example: String? = nil,
        exampleRu: String? = nil,
        textId: String? = nil,
        created: Date = Date()
    ) {
        let pl = PolishText.nfc(pl.collapsingWhitespace)
        let ru = ru.trimmed
        let base = PolishText.nfc(base.collapsingWhitespace)
        self.id = Flashcard.makeID(pl: pl, ru: ru)
        self.pl = pl
        self.ru = ru
        self.base = PolishText.dedupKey(base) == PolishText.dedupKey(pl) ? "" : base
        self.form = form.trimmed
        self.alternation = alternation.trimmed
        self.note = note.trimmed
        self.topic = topic
        self.source = source
        self.photoId = photoId
        self.created = created
        self.box = 0
        self.due = created
        self.right = 0
        self.wrong = 0
        self.example = example
        self.exampleRu = exampleRu
        self.textId = textId
    }

    /// Stable id: slug(pl) + hash(pl + ru).
    static func makeID(pl: String, ru: String) -> String {
        let slug = PolishText.slug(pl)
        return (slug.isEmpty ? "card" : slug) + "-" + PolishText.stableHash(pl + ru)
    }

    var dedupKey: String {
        PolishText.dedupKey(pl)
    }

    /// "rzeka → rzece (k→c)", shown after an answer to fix the alternation in memory.
    var formLine: String? {
        let alternationPart = alternation.isEmpty ? "" : " (\(alternation))"
        if !base.isEmpty { return "\(base) → \(pl)\(alternationPart)" }
        return alternation.isEmpty ? nil : "\(pl)\(alternationPart)"
    }

    private enum CodingKeys: String, CodingKey {
        case id, pl, ru, base, form, alternation, note, topic, source, photoId, created
        case box, due, right, wrong, example, exampleRu, textId
    }

    // Lenient decoding: fields added in later versions must not break older saved data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pl = try c.decode(String.self, forKey: .pl)
        ru = try c.decodeIfPresent(String.self, forKey: .ru) ?? ""
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? Flashcard.makeID(pl: pl, ru: ru)
        base = try c.decodeIfPresent(String.self, forKey: .base) ?? ""
        form = try c.decodeIfPresent(String.self, forKey: .form) ?? ""
        alternation = try c.decodeIfPresent(String.self, forKey: .alternation) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        topic = try c.decodeIfPresent(String.self, forKey: .topic) ?? Flashcard.defaultTopic
        source = try c.decodeIfPresent(CardSource.self, forKey: .source) ?? .manual
        photoId = try c.decodeIfPresent(String.self, forKey: .photoId)
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        box = try c.decodeIfPresent(Int.self, forKey: .box) ?? 0
        due = try c.decodeIfPresent(Date.self, forKey: .due) ?? created
        right = try c.decodeIfPresent(Int.self, forKey: .right) ?? 0
        wrong = try c.decodeIfPresent(Int.self, forKey: .wrong) ?? 0
        example = try c.decodeIfPresent(String.self, forKey: .example)
        exampleRu = try c.decodeIfPresent(String.self, forKey: .exampleRu)
        textId = try c.decodeIfPresent(String.self, forKey: .textId)
    }
}
