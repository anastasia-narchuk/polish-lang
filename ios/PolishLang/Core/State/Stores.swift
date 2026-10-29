import Foundation
import Observation

/// Where the app keeps its data: Application Support/PolishLang.
enum AppDirectories {
    static let data: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PolishLang", isDirectory: true)
    }()
}

/// All flashcards. Newest first.
@MainActor
@Observable
final class CardStore {
    private(set) var cards: [Flashcard]
    /// Changes on every edit; views use it to refresh derived data such as text highlights.
    private(set) var revision = 0
    private(set) var saveError: String?
    @ObservationIgnored private let file: JSONFileStore<Flashcard>

    init(file: JSONFileStore<Flashcard>) {
        self.file = file
        cards = file.load()
    }

    var dedupKeys: Set<String> {
        Set(cards.map(\.dedupKey))
    }

    func contains(form: String) -> Bool {
        let key = PolishText.dedupKey(form)
        return !key.isEmpty && cards.contains { $0.dedupKey == key }
    }

    func card(id: String) -> Flashcard? {
        cards.first { $0.id == id }
    }

    func dueCount(now: Date = Date()) -> Int {
        cards.filter { $0.due <= now }.count
    }

    /// Forms and base forms to highlight in texts: what the learner already studies.
    var highlightPhrases: [String] {
        cards.flatMap { $0.base.isEmpty ? [$0.pl] : [$0.pl, $0.base] }
    }

    func add(_ newCards: [Flashcard]) {
        guard !newCards.isEmpty else { return }
        cards.insert(contentsOf: newCards, at: 0)
        persist()
    }

    func update(_ card: Flashcard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index] = card
        persist()
    }

    func delete(ids: Set<String>) {
        cards.removeAll { ids.contains($0.id) }
        persist()
    }

    private func persist() {
        revision += 1
        do {
            try file.save(cards)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// The mistake bank of the review.
@MainActor
@Observable
final class MistakeStore {
    static let limit = 1_000

    private(set) var mistakes: [Mistake]
    @ObservationIgnored private let file: JSONFileStore<Mistake>

    init(file: JSONFileStore<Mistake>) {
        self.file = file
        mistakes = file.load()
    }

    var cardIDs: Set<String> {
        Set(mistakes.map(\.cardId))
    }

    func counts() -> [(type: SpellingErrorType, count: Int)] {
        var counts: [SpellingErrorType: Int] = [:]
        for mistake in mistakes {
            for type in mistake.types { counts[type, default: 0] += 1 }
        }
        return SpellingErrorType.allCases.compactMap { type -> (type: SpellingErrorType, count: Int)? in
            guard let count = counts[type] else { return nil }
            return (type: type, count: count)
        }
    }

    func record(_ mistake: Mistake) {
        mistakes.insert(mistake, at: 0)
        if mistakes.count > Self.limit { mistakes.removeLast(mistakes.count - Self.limit) }
        try? file.save(mistakes)
    }

    func removeAll(forCards ids: Set<String>) {
        mistakes.removeAll { ids.contains($0.cardId) }
        try? file.save(mistakes)
    }

    func clear() {
        mistakes = []
        try? file.save(mistakes)
    }
}

/// History of generated texts (TZ 2, section 6). Newest first.
@MainActor
@Observable
final class ReadingStore {
    private(set) var texts: [ReadingText]
    @ObservationIgnored private let file: JSONFileStore<ReadingText>

    init(file: JSONFileStore<ReadingText>) {
        self.file = file
        texts = file.load()
    }

    func contains(id: String) -> Bool {
        texts.contains { $0.id == id }
    }

    func save(_ text: ReadingText) {
        guard !contains(id: text.id) else { return }
        texts.insert(text, at: 0)
        try? file.save(texts)
    }

    func delete(id: String) {
        texts.removeAll { $0.id == id }
        try? file.save(texts)
    }
}

/// Photos the cards were recognized from. One batch (up to 3 photos) per id.
@MainActor
final class PhotoStore {
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// Saves JPEG data and returns the batch id, or nil if nothing could be written.
    func save(_ photos: [Data]) -> String? {
        let id = UUID().uuidString
        let folder = directory.appendingPathComponent(id, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (index, data) in photos.enumerated() {
                try data.write(to: folder.appendingPathComponent("\(index).jpg"), options: .atomic)
            }
            return id
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
    }

    func photos(for id: String) -> [URL] {
        let folder = directory.appendingPathComponent(id, isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".jpg") }.sorted().map { folder.appendingPathComponent($0) }
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(id, isDirectory: true))
    }
}
