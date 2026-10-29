import Foundation

/// Everything the learner created, as one JSON file to keep or move to another device.
struct Backup: Codable {
    var exported: Date
    var cards: [Flashcard]
    var texts: [ReadingText]
    var mistakes: [Mistake]

    func write(to directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let url = directory.appendingPathComponent("polish-lang-\(formatter.string(from: exported)).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
        return url
    }
}
