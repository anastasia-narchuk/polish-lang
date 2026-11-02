import Foundation
import Observation

/// Numbers of the exam that are not confirmed (TZ 3, section 2): the learner checks them
/// against a sample test ("Przykładowe testy") and changes them in the settings.
struct WritingSettings: Codable, Equatable, Sendable {
    struct Pair: Codable, Equatable, Sendable {
        var short: Int
        var long: Int

        func value(_ length: TaskLength) -> Int {
            length == .short ? short : long
        }
    }

    var examLevel: ExamLevel = .b1
    var wordsB1 = Pair(short: 50, long: 150)
    var wordsB2 = Pair(short: 120, long: 250)
    /// The 30 points of the module split between the short and the long task.
    var points = Pair(short: 10, long: 20)
    var minutesB1 = 60
    var minutesB2 = 75
    /// The ą ć ę ł ń ó ś ź ż bar over the keyboard.
    var lettersBar = true

    func words(_ level: ExamLevel, _ length: TaskLength) -> Int {
        (level == .b1 ? wordsB1 : wordsB2).value(length)
    }

    func weight(_ length: TaskLength) -> Int {
        points.value(length)
    }

    func minutes(_ level: ExamLevel) -> Int {
        level == .b1 ? minutesB1 : minutesB2
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case examLevel, wordsB1, wordsB2, points, minutesB1, minutesB2, lettersBar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WritingSettings()
        examLevel = try c.decodeIfPresent(ExamLevel.self, forKey: .examLevel) ?? defaults.examLevel
        wordsB1 = try c.decodeIfPresent(Pair.self, forKey: .wordsB1) ?? defaults.wordsB1
        wordsB2 = try c.decodeIfPresent(Pair.self, forKey: .wordsB2) ?? defaults.wordsB2
        points = try c.decodeIfPresent(Pair.self, forKey: .points) ?? defaults.points
        minutesB1 = try c.decodeIfPresent(Int.self, forKey: .minutesB1) ?? defaults.minutesB1
        minutesB2 = try c.decodeIfPresent(Int.self, forKey: .minutesB2) ?? defaults.minutesB2
        lettersBar = try c.decodeIfPresent(Bool.self, forKey: .lettersBar) ?? defaults.lettersBar
    }
}

/// Checked texts, newest first (TZ 3, 4.7).
@MainActor
@Observable
final class WritingStore {
    private(set) var texts: [WritingText]
    @ObservationIgnored private let file: JSONFileStore<WritingText>

    init(file: JSONFileStore<WritingText>) {
        self.file = file
        texts = file.load()
    }

    func text(id: String) -> WritingText? {
        texts.first { $0.id == id }
    }

    func save(_ text: WritingText) {
        texts.removeAll { $0.id == text.id }
        texts.insert(text, at: 0)
        try? file.save(texts)
    }

    func delete(id: String) {
        texts.removeAll { $0.id == id }
        try? file.save(texts)
    }
}

/// An entry of the bank of mistakes from texts (TZ 3, section 8).
struct TextErrorEntry: Identifiable, Codable, Hashable, Sendable {
    static let registerID = "e_rejestr"

    var id: String
    var fragment: String
    var correction: String
    /// ortografia, gramatyka, leksyka, składnia, interpunkcja or rejestr.
    var type: String
    /// Spelling subcategory: ó/u, rz/ż, ch/h, ą/ę, nie, ogonki.
    var cat: String?
    var ruleRu: String
    var count: Int
    var lastSeen: Date
    var drilled: Int
    var source: String

    /// id = hash(fragment → correction).
    static func id(fragment: String, correction: String) -> String {
        "e_" + PolishText.stableHash(PolishText.dedupKey(fragment) + "→" + PolishText.dedupKey(correction) + "|" + fragment + "→" + correction)
    }

    /// A line of "Мои ловушки".
    var trapLine: String {
        if id == Self.registerID { return "Pan/Pani или ty — не смешивай" }
        let pair = "\(fragment) → \(correction)"
        return cat.map { "\($0): \(pair)" } ?? pair
    }
}

/// Mistakes from checked texts. Traps are the top 3 by count × 1 / days since last seen.
@MainActor
@Observable
final class TextErrorStore {
    static let limit = 2_000

    private(set) var entries: [TextErrorEntry]
    @ObservationIgnored private let file: JSONFileStore<TextErrorEntry>

    init(file: JSONFileStore<TextErrorEntry>) {
        self.file = file
        entries = file.load()
    }

    /// Records the errors of one check and its register problems.
    func record(_ check: TextCheck, source: String, now: Date = Date()) {
        for error in check.errors {
            let id = TextErrorEntry.id(fragment: error.fragment, correction: error.correction)
            let cat = error.type == "ortografia" ? WritingRules.spellingCategory(fragment: error.fragment, correction: error.correction) : nil
            bump(id: id, now: now) {
                TextErrorEntry(id: id, fragment: error.fragment, correction: error.correction, type: error.type.isEmpty ? "ortografia" : error.type,
                               cat: cat, ruleRu: error.ruleRu, count: 1, lastSeen: now, drilled: 0, source: source)
            }
        }
        if !check.register.consistent || !check.register.issuesRu.isEmpty {
            let rule = check.register.issuesRu.first ?? "Регистр: Pan/Pani или ty — не смешивай в одном тексте."
            bump(id: TextErrorEntry.registerID, now: now) {
                TextErrorEntry(id: TextErrorEntry.registerID, fragment: "", correction: "", type: "rejestr", cat: nil,
                               ruleRu: rule, count: 1, lastSeen: now, drilled: 0, source: source)
            }
        }
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
        try? file.save(entries)
    }

    func traps(now: Date = Date(), limit: Int = 3) -> [TextErrorEntry] {
        func weight(_ entry: TextErrorEntry) -> Double {
            let days = max(1, now.timeIntervalSince(entry.lastSeen) / 86_400)
            return Double(entry.count) / days
        }
        return entries
            .sorted { weight($0) == weight($1) ? $0.lastSeen > $1.lastSeen : weight($0) > weight($1) }
            .prefix(limit)
            .map { $0 }
    }

    func clear() {
        entries = []
        try? file.save(entries)
    }

    private func bump(id: String, now: Date, make: () -> TextErrorEntry) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].count += 1
            entries[index].lastSeen = now
            let entry = entries.remove(at: index)
            entries.insert(entry, at: 0)
        } else {
            entries.insert(make(), at: 0)
        }
    }
}

/// The text being written, saved 2 s after the last change so nothing is lost (TZ 3, 4.2).
struct WritingDraft: Codable, Hashable, Sendable {
    var mode: WritingMode
    var task: WritingTask
    var text: String
    var ideasDraft: String
    var hand: Bool
    var started: Date
    var support: SupportStats
    var revealedIdeas: [Int]
    var checklist: WritingChecklist
    var transcript: String?
    var photoId: String?
}

@MainActor
final class WritingDraftStore {
    private let file: JSONFileStore<WritingDraft>

    init(file: JSONFileStore<WritingDraft>) {
        self.file = file
    }

    func load() -> WritingDraft? {
        file.load().first
    }

    func save(_ draft: WritingDraft) {
        try? file.save([draft])
    }

    func clear() {
        try? file.save([])
    }
}
