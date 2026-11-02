import XCTest
@testable import PolishCore

final class StorageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("polish-core-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCardsRoundTrip() throws {
        let store = JSONFileStore<Flashcard>(url: directory.appendingPathComponent("cards.json"))
        XCTAssertEqual(store.load(), [])
        var card = Flashcard(pl: "rzece", ru: "реке", base: "rzeka", alternation: "k→c", source: .photo, photoId: "p1",
                             created: Date(timeIntervalSince1970: 1_800_000_000))
        card.box = 2
        try store.save([card])
        XCTAssertEqual(store.load(), [card])
    }

    func testOlderRecordsWithoutNewFieldsStillLoad() throws {
        let url = directory.appendingPathComponent("cards.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"[{"pl":"kot","ru":"кот","source":"something-new"}]"#.utf8).write(to: url)
        let cards = JSONFileStore<Flashcard>(url: url).load()
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].source, .manual)
        XCTAssertEqual(cards[0].topic, "moje")
        XCTAssertEqual(cards[0].box, 0)
        XCTAssertEqual(cards[0].id, Flashcard.makeID(pl: "kot", ru: "кот"))
    }

    func testUnreadableFileIsKeptAside() throws {
        let url = directory.appendingPathComponent("texts.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(JSONFileStore<ReadingText>(url: url).load(), [])
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("texts.unreadable-") })
    }

    func testReadingTextRoundTrip() throws {
        let store = JSONFileStore<ReadingText>(url: directory.appendingPathComponent("texts.json"))
        let text = ReadingText(
            created: Date(timeIntervalSince1970: 1_800_000_000),
            topic: "zdrowie", level: .a2, kind: .dialogue, title: "U lekarza",
            paragraphs: ["— Dzień dobry!", "— Dzień dobry, co pani dolega?"],
            keyWords: [KeyWord(form: "dolega", base: "dolegać", ru: "беспокоит")],
            usedMyWords: ["lekarza"]
        )
        XCTAssertEqual(text.wordCount, 7)
        try store.save([text])
        XCTAssertEqual(store.load(), [text])
    }

    func testSlugAndHash() {
        XCTAssertEqual(PolishText.slug("Przy rzece, książce!"), "przy-rzece-ksiazce")
        XCTAssertEqual(PolishText.stableHash("rzeceреке"), PolishText.stableHash("rzeceреке"))
        XCTAssertEqual(PolishText.stableHash("").count, 8)
        XCTAssertEqual(PolishText.dedupKey("  Przy   rzece! "), "przy rzece")
        XCTAssertEqual(PolishText.fold("Zażółć gęślą jaźń"), "Zazolc gesla jazn")
        XCTAssertTrue(PolishText.containsCyrillic("dom дом"))
        XCTAssertFalse(PolishText.containsCyrillic("Zażółć gęślą jaźń"))
    }
}
