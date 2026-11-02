import Foundation

/// A versioned list saved as one JSON file.
struct StoredList<Item: Codable>: Codable {
    var version: Int
    var items: [Item]
}

/// Reads and writes a list of records as JSON (ISO 8601 dates, atomic writes).
struct JSONFileStore<Item: Codable> {
    static var currentVersion: Int { 1 }

    let url: URL

    /// Missing file → empty list. A file that cannot be read is moved aside, not overwritten.
    func load() -> [Item] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let stored = try? decoder.decode(StoredList<Item>.self, from: data) {
            return stored.items
        }
        if let plain = try? decoder.decode([Item].self, from: data) {
            return plain
        }
        let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: backup)
        return []
    }

    func save(_ items: [Item]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(items).write(to: url, options: .atomic)
    }

    func encode(_ items: [Item]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(StoredList(version: Self.currentVersion, items: items))
    }
}
