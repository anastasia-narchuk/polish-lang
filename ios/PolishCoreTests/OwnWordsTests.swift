import XCTest
@testable import PolishCore

/// TZ 1: own words into flashcards. Numbers refer to the acceptance criteria in section 8.
final class OwnWordsTests: XCTestCase {
    // MARK: List parsing (section 2.2)

    func testSingleLineWithCommasIsSplit() {
        // Criterion 6.
        let entries = OwnListParser.parse("morzu, przy rzece, poszłam")
        XCTAssertEqual(entries.map(\.pl), ["morzu", "przy rzece", "poszłam"])
    }

    func testCommasStayInsidePhraseWhenThereIsATranslation() {
        let entries = OwnListParser.parse("tak, jak — так, как")
        XCTAssertEqual(entries, [ParsedEntry(pl: "tak, jak", ru: "так, как")])
    }

    func testCommasStayInsidePhrasesOnSeveralLines() {
        let entries = OwnListParser.parse("tak, jak\nrzece")
        XCTAssertEqual(entries.map(\.pl), ["tak, jak", "rzece"])
    }

    func testAllLineFormats() {
        let input = """
        rzece
        rzece — реке
        rzece [rzeka]
        rzece [rzeka] — реке
        załatwić sprawę – уладить дело
        biało-czerwony - бело-красный
        kot\tкот

        """
        let entries = OwnListParser.parse(input)
        XCTAssertEqual(entries, [
            ParsedEntry(pl: "rzece"),
            ParsedEntry(pl: "rzece", ru: "реке"),
            ParsedEntry(pl: "rzece", base: "rzeka"),
            ParsedEntry(pl: "rzece", base: "rzeka", ru: "реке"),
            ParsedEntry(pl: "załatwić sprawę", ru: "уладить дело"),
            ParsedEntry(pl: "biało-czerwony", ru: "бело-красный"),
            ParsedEntry(pl: "kot", ru: "кот"),
        ])
    }

    func testListMarkersAreStripped() {
        let entries = OwnListParser.parse("1. rzece\n2) morzu\n- kot — кот\n• dom")
        XCTAssertEqual(entries.map(\.pl), ["rzece", "morzu", "kot", "dom"])
        XCTAssertEqual(entries[2].ru, "кот")
    }

    func testRowsWithTranslationSkipAIWhenBaseIsNotWanted() {
        // Criterion 6: "załatwić sprawę — уладить дело" and "kot\tкот" do not go to AI.
        let drafts = OwnListParser.parse("załatwić sprawę — уладить дело\nkot\tкот\nrzece")
            .map { CardDraft(entry: $0, source: .list) }
        XCTAssertEqual(drafts.map { $0.needsAI(wantBase: false) }, [false, false, true])
        XCTAssertEqual(drafts.map { $0.needsAI(wantBase: true) }, [true, true, true])
        let withBase = CardDraft(entry: ParsedEntry(pl: "kot", base: "kot", ru: "кот"), source: .list)
        XCTAssertFalse(withBase.needsAI(wantBase: true))
    }

    // MARK: Translation pipeline (section 4.1)

    func testEnrichPromptListsFormsAndLearnerBaseForms() {
        let prompt = Prompts.enrich([EnrichInput(pl: "rzece"), EnrichInput(pl: "poszłam", base: "pójść")])
        XCTAssertTrue(prompt.contains("1. rzece\n2. poszłam [pójść]\n"))
        XCTAssertTrue(prompt.contains("Niczego nie zmieniaj w samej formie"))
    }

    func testRzeceKeepsTheFormAndGetsTranslationOfTheForm() async throws {
        // Criteria 1 and 9.
        let reply = #"{"items":[{"ru":"реке (дат./предл. п.)","base":"rzeka","baseCheck":"","form":"C./Msc. l.poj.","alternation":"k→c","note":"rzeka → rzece, C./Msc. l.poj., k→c","fix":"","isPolish":true}]}"#
        let transport = MockTransport([messageReply(reply)])
        let ai = PolishAI(client: AnthropicClient(transport: transport), config: testConfig())

        var draft = CardDraft(entry: OwnListParser.parse("rzece")[0], source: .manual)
        let outcome = await ai.enrich([draft.enrichInput])
        XCTAssertNil(outcome.failure)
        draft.apply(outcome.results[0])

        XCTAssertEqual(draft.ru, "реке (дат./предл. п.)")
        XCTAssertEqual(draft.base, "rzeka")
        XCTAssertEqual(draft.alternation, "k→c")
        let saved = DraftBuilder.save([draft], existingKeys: [], photoId: nil)
        XCTAssertEqual(saved.cards.map(\.pl), ["rzece"])
        XCTAssertEqual(saved.cards[0].formLine, "rzeka → rzece (k→c)")
    }

    func testLearnerBaseFormIsKeptAndOnlyChecked() {
        // Criteria 3 and 4.
        var correct = CardDraft(entry: OwnListParser.parse("poszłam [pójść]")[0], source: .manual)
        correct.apply(EnrichResult(ru: "(я) пошла", base: "pójść", baseCheck: "", form: "cz. przeszły, 1 os. l.poj., ż."))
        XCTAssertEqual(correct.base, "pójść")
        XCTAssertEqual(correct.baseCheck, "")
        XCTAssertEqual(correct.ru, "(я) пошла")

        var wrong = CardDraft(entry: OwnListParser.parse("poszłam [iść]")[0], source: .manual)
        wrong.apply(EnrichResult(ru: "(я) пошла", base: "pójść", baseCheck: "Видовая пара: poszłam — от pójść (сов. вид), iść — несов. вид."))
        XCTAssertEqual(wrong.base, "iść", "the learner's base form stays until she changes it")
        XCTAssertFalse(wrong.baseCheck.isEmpty)
    }

    func testSpellingFixIsOnlyASuggestion() {
        // Criterion 5.
        var draft = CardDraft(entry: ParsedEntry(pl: "ksiazce"), source: .manual)
        draft.apply(EnrichResult(ru: "книге (дат./предл. п.)", base: "książka", fix: "książce"))
        XCTAssertEqual(draft.fix, "książce")
        XCTAssertEqual(DraftBuilder.save([draft], existingKeys: [], photoId: nil).cards.map(\.pl), ["ksiazce"])

        draft.applyFix()
        XCTAssertEqual(DraftBuilder.save([draft], existingKeys: [], photoId: nil).cards.map(\.pl), ["książce"])
    }

    func testNotPolishRowIsUnchecked() {
        var draft = CardDraft(entry: ParsedEntry(pl: "house"), source: .list)
        draft.apply(EnrichResult(ru: "дом", isPolish: false))
        XCTAssertFalse(draft.include)
        XCTAssertFalse(draft.isPolish)
    }

    func testMissingRepliesAreMarked() throws {
        let results = try ResponseParser.enrichResults(from: #"{"items":[{"ru":"реке","isPolish":true}]}"#, count: 3)
        XCTAssertEqual(results.count, 3)
        XCTAssertNotNil(results[0])
        XCTAssertNil(results[1])
        var draft = CardDraft(entry: ParsedEntry(pl: "morzu"), source: .list)
        draft.apply(results[1])
        XCTAssertTrue(draft.missingFromReply)
    }

    func testRetryDoesNotOverwriteLearnerEdits() {
        var draft = CardDraft(entry: ParsedEntry(pl: "rzece"), source: .manual)
        draft.ru = "у реки"
        draft.apply(EnrichResult(ru: "реке (дат./предл. п.)", base: "rzeka"))
        XCTAssertEqual(draft.ru, "у реки")
        XCTAssertEqual(draft.base, "rzeka")
    }

    func testBatchesOfForty() async {
        let inputs = (1...85).map { EnrichInput(pl: "słowo\($0)") }
        func reply(_ count: Int) -> MockTransport.Reply {
            let items = Array(repeating: #"{"ru":"слово","base":"","baseCheck":"","form":"","alternation":"","note":"","fix":"","isPolish":true}"#, count: count)
            return messageReply("{\"items\":[\(items.joined(separator: ","))]}")
        }
        let transport = MockTransport([reply(40), reply(40), reply(5)])
        let outcome = await PolishAI(client: AnthropicClient(transport: transport), config: testConfig()).enrich(inputs)
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertEqual(outcome.results.count, 85)
        XCTAssertTrue(outcome.results.allSatisfy { $0 != nil })
        XCTAssertNil(outcome.failure)
    }

    func testFailedBatchKeepsEarlierResults() async {
        let items = Array(repeating: #"{"ru":"слово","isPolish":true}"#, count: 40).joined(separator: ",")
        let transport = MockTransport([
            messageReply("{\"items\":[\(items)]}"),
            messageReply("Извините, не могу."),
        ])
        let inputs = (1...50).map { EnrichInput(pl: "słowo\($0)") }
        let outcome = await PolishAI(client: AnthropicClient(transport: transport), config: testConfig()).enrich(inputs)
        XCTAssertEqual(outcome.failure, .invalidResponse)
        XCTAssertEqual(outcome.results.prefix(40).compactMap { $0 }.count, 40)
        XCTAssertEqual(outcome.results.suffix(10).compactMap { $0 }.count, 0)
    }

    // MARK: Duplicates (section 5)

    func testDuplicatesAreCountedAndDifferentFormsAreKept() {
        // Criterion 8, and "rzeka" vs "rzece" are different cards.
        let existing: Set<String> = [PolishText.dedupKey("rzece")]
        let drafts = OwnListParser.parse("Rzece!\nrzeka\nrzeka\nprzy  rzece")
            .map { CardDraft(entry: $0, source: .list) }
        let prepared = DraftBuilder.prepare(drafts, existingKeys: existing)
        XCTAssertEqual(prepared.drafts.map(\.pl), ["rzeka", "przy rzece"])
        XCTAssertEqual(prepared.duplicates, 2)
    }

    func testRowsWithoutTranslationAreNotSaved() {
        var withTranslation = CardDraft(entry: ParsedEntry(pl: "kot", ru: "кот"), source: .list)
        withTranslation.include = true
        let without = CardDraft(entry: ParsedEntry(pl: "pies"), source: .list)
        var unchecked = CardDraft(entry: ParsedEntry(pl: "dom", ru: "дом"), source: .list)
        unchecked.include = false
        let result = DraftBuilder.save([withTranslation, without, unchecked], existingKeys: [], photoId: nil)
        XCTAssertEqual(result.cards.map(\.pl), ["kot"])
        XCTAssertEqual(result.skippedWithoutTranslation, 1)
        XCTAssertEqual(result.message, "Добавлено: 1. Без перевода не сохраняю")
    }

    func testCardIdIsStable() {
        let first = Flashcard(pl: "przy rzece", ru: "у реки", source: .manual)
        let second = Flashcard(pl: "przy rzece", ru: "у реки", source: .list)
        XCTAssertEqual(first.id, second.id)
        XCTAssertTrue(first.id.hasPrefix("przy-rzece-"))
        XCTAssertNotEqual(first.id, Flashcard(pl: "przy rzece", ru: "возле реки", source: .manual).id)
    }

    func testBaseEqualToFormIsStoredEmpty() {
        XCTAssertEqual(Flashcard(pl: "kot", ru: "кот", base: "Kot", source: .manual).base, "")
        XCTAssertEqual(Flashcard(pl: "kota", ru: "кота", base: "kot", source: .manual).base, "kot")
    }

    // MARK: Photo (section 4.2)

    func testPhotoItemsKeepWrittenFormAndConfidence() throws {
        let reply = #"{"items":[{"pl":"rzece","ru":"","base":"","confidence":"high"},{"pl":"ksi[?]żce","ru":"книге","base":"","confidence":"low"},{"pl":"rzece","ru":"","base":"","confidence":"high"}]}"#
        let items = try ResponseParser.photoItems(from: reply)
        XCTAssertEqual(items.map(\.pl), ["rzece", "ksi[?]żce"])
        XCTAssertEqual(items.map(\.lowConfidence), [false, true])
        let lowDraft = CardDraft(entry: ParsedEntry(pl: items[1].pl, ru: items[1].ru), source: .photo, lowConfidence: true)
        XCTAssertFalse(lowDraft.include)
    }

    func testPhotoRequestCarriesImagesBeforeText() throws {
        let client = AnthropicClient(transport: MockTransport([]))
        let request = AIRequest(
            prompt: Prompts.photo(mode: .highlighted),
            images: [AIImage(mediaType: "image/jpeg", data: Data([1, 2, 3]))],
            maxTokens: 100, effort: .medium, schema: Schemas.photo
        )
        let body = try XCTUnwrap(JSONValue.decode(client.makeURLRequest(request, config: testConfig(), fallback: false).httpBody!))
        let content = try XCTUnwrap(body["messages"]?.arrayValue?.first?["content"]?.arrayValue)
        XCTAssertEqual(content.map { $0["type"]?.stringValue }, ["image", "text"])
        XCTAssertEqual(content[0]["source"]?["data"]?.stringValue, "AQID")
        XCTAssertTrue(content[1]["text"]?.stringValue?.contains("TYLKO polskie słowa i frazy wyróżnione") == true)
    }
}
