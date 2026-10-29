import XCTest
@testable import PolishCore

/// Screen models with a fake Claude API: what the user sees after each step.
@MainActor
final class ScreenModelTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("polish-screen-tests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeApp(replies: [MockTransport.Reply], key: String? = "sk-ant-test") -> (AppModel, MockTransport) {
        let secrets = InMemorySecretStore()
        if let key { secrets.save(key, account: "anthropic-api-key") }
        let defaults = UserDefaults(suiteName: "polish-tests-\(UUID().uuidString)")!
        let app = AppModel(directory: directory, secrets: secrets, defaults: defaults)
        let transport = MockTransport(replies)
        app.ai.client = AnthropicClient(transport: transport)
        return (app, transport)
    }

    private static let lekarzText = #"{"title":"U lekarza","paragraphs":["Idę do lekarza. Mam katar.","Lekarz jest miły."],"keyWords":[{"form":"do lekarza","base":"lekarz","ru":"к врачу"}],"usedMyWords":[]}"#

    // MARK: Reading

    func testGenerationOpensReaderAndSavesToHistory() async {
        let (app, transport) = makeApp(replies: [messageReply(Self.lekarzText)])
        let session = app.reading
        session.topic = "wizyta u lekarza"
        app.settings.readingLevel = .a1
        session.generate()
        XCTAssertTrue(session.isGenerating)
        await session.waitForGeneration()

        XCTAssertEqual(session.phase, .idle)
        XCTAssertEqual(session.current?.title, "U lekarza")
        XCTAssertEqual(session.current?.level, .a1)
        XCTAssertEqual(session.path, [.reader])
        XCTAssertNotNil(session.warning, "8 words is too short for A1")
        XCTAssertTrue(session.isCurrentSaved, "autosave is on by default")
        XCTAssertEqual(app.readings.texts.count, 1)
        let prompt = transport.lastBody?["messages"]?.arrayValue?.first?["content"]?.arrayValue?.last?["text"]?.stringValue ?? ""
        XCTAssertTrue(prompt.contains("Poziom: A1."))
    }

    func testEasierAndHarderKeepTheTopic() async {
        // TZ 2, criterion 4.
        let (app, transport) = makeApp(replies: [messageReply(Self.lekarzText), messageReply(Self.lekarzText)])
        let session = app.reading
        session.topic = "wizyta u lekarza"
        session.generate()
        await session.waitForGeneration()
        session.regenerate(level: session.current?.level.harder)
        await session.waitForGeneration()

        XCTAssertEqual(session.current?.level, .b2)
        XCTAssertEqual(session.current?.topic, "wizyta u lekarza")
        XCTAssertEqual(session.path, [.reader])
        let prompt = transport.lastBody?["messages"]?.arrayValue?.first?["content"]?.arrayValue?.last?["text"]?.stringValue ?? ""
        XCTAssertTrue(prompt.contains("Poziom: B2."))
        XCTAssertTrue(prompt.contains("wizyta u lekarza"))
    }

    func testRefusalAndMissingKeyMessages() async {
        let (refusing, _) = makeApp(replies: [MockTransport.Reply(status: 200, body: #"{"content":[],"stop_reason":"refusal"}"#)])
        refusing.reading.topic = "coś"
        refusing.reading.generate()
        await refusing.reading.waitForGeneration()
        XCTAssertEqual(refusing.reading.phase, .failed(message: "Не получилось сгенерировать текст на эту тему. Попробуй другую формулировку.", canRetry: false))

        let (noKey, transport) = makeApp(replies: [], key: nil)
        noKey.reading.topic = "praca"
        noKey.reading.generate()
        await noKey.reading.waitForGeneration()
        guard case .failed(let message, _) = noKey.reading.phase else { return XCTFail("expected a failure") }
        XCTAssertTrue(message.contains("API-ключ"))
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testSixthGenerationInAMinuteWaits() async {
        let (app, transport) = makeApp(replies: Array(repeating: messageReply(Self.lekarzText), count: 6))
        app.settings.autosaveTexts = false
        let session = app.reading
        session.topic = "praca"
        for _ in 0..<5 {
            session.generate()
            await session.waitForGeneration()
        }
        session.generate()
        await session.waitForGeneration()
        guard case .cooldown(let until) = session.phase else { return XCTFail("expected a cooldown, got \(session.phase)") }
        XCTAssertGreaterThan(until, Date())
        XCTAssertEqual(transport.requests.count, 5)
        XCTAssertTrue(app.readings.texts.isEmpty, "autosave off: nothing in the history until saved")
        session.saveCurrent()
        XCTAssertEqual(app.readings.texts.count, 1)
    }

    func testCyrillicTextIsRejected() async {
        let reply = #"{"title":"Dom","paragraphs":["To jest dom (дом)."],"keyWords":[],"usedMyWords":[]}"#
        let (app, _) = makeApp(replies: [messageReply(reply)])
        app.reading.topic = "dom"
        app.reading.generate()
        await app.reading.waitForGeneration()
        XCTAssertNil(app.reading.current)
        guard case .failed(_, let canRetry) = app.reading.phase else { return XCTFail("expected a failure") }
        XCTAssertTrue(canRetry)
    }

    func testMyWordsAreSentAndHighlighted() async {
        let reply = #"{"title":"Nad rzeką","paragraphs":["Mieszkam przy rzece. Lekarza nie ma."],"keyWords":[],"usedMyWords":["rzece","lekarza","zupa"]}"#
        let (app, transport) = makeApp(replies: [messageReply(reply)])
        app.cards.add([
            Flashcard(pl: "rzekę", ru: "реку", base: "rzeka", source: .manual),
            Flashcard(pl: "lekarz", ru: "врач", source: .manual),
        ])
        app.reading.topic = "miasto"
        app.reading.useMyWords = true
        app.reading.generate()
        await app.reading.waitForGeneration()

        let prompt = transport.lastBody?["messages"]?.arrayValue?.first?["content"]?.arrayValue?.last?["text"]?.stringValue ?? ""
        XCTAssertTrue(prompt.contains("Wpleć naturalnie te słowa"))
        XCTAssertTrue(prompt.contains("rzeka") && prompt.contains("lekarz"))
        XCTAssertEqual(app.reading.current?.usedMyWords, ["rzece", "lekarza"], "a word missing from the text is dropped")
        XCTAssertEqual(app.reading.requestedMyWords, 2)

        let reader = ReaderModel(text: app.reading.current!)
        let highlighted = reader.document.paragraphs[0].tokens.filter { reader.myWordTokens.contains($0.id) }.map(\.text)
        XCTAssertEqual(highlighted, ["rzece", "Lekarza"])
    }

    // MARK: Reader

    func testTapTranslatesWithCacheAndAddsTheFormFromTheText() async throws {
        // TZ 2, criteria 5 and 6.
        let translation = #"{"ru":"врача (род./вин. п.)","base":"lekarz","pos":"существительное","form":"D./B. l.poj.","alternation":"","note":"","sentence_ru":"Я иду к врачу."}"#
        let (app, transport) = makeApp(replies: [messageReply(Self.lekarzText), messageReply(translation)])
        app.reading.topic = "zdrowie"
        app.reading.generate()
        await app.reading.waitForGeneration()
        let reader = ReaderModel(text: try XCTUnwrap(app.reading.current))
        let word = try XCTUnwrap(reader.document.paragraphs[0].tokens.first { $0.text == "lekarza" })

        let selection = try XCTUnwrap(reader.tap(tokenID: word.id))
        reader.translate(selection, ai: app.ai, session: app.reading)
        XCTAssertEqual(reader.translation, .loading)
        XCTAssertTrue(reader.panelPresented)
        await reader.waitForRequests()
        XCTAssertEqual(reader.loadedTranslation?.ru, "врача (род./вин. п.)")

        let card = try XCTUnwrap(reader.candidateCard())
        XCTAssertEqual(card.pl, "lekarza")
        XCTAssertEqual(card.base, "lekarz")
        XCTAssertEqual(card.example, "Idę do lekarza.")
        XCTAssertEqual(card.exampleRu, "Я иду к врачу.")
        XCTAssertEqual(card.source, .text)
        XCTAssertEqual(card.textId, app.reading.current?.id)

        // A second tap on the same word does not cost a request.
        reader.panelClosed()
        reader.translate(selection, ai: app.ai, session: app.reading)
        XCTAssertEqual(reader.loadedTranslation?.ru, "врача (род./вин. п.)")
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testBaseFormSwitchSavesTheBaseForm() async throws {
        let translation = #"{"ru":"реке (дат./предл. п.)","base":"rzeka","pos":"существительное","form":"Msc. l.poj.","alternation":"k→c","note":"","sentence_ru":"Мы гуляли у реки."}"#
        let base = #"{"items":[{"ru":"река","base":"rzeka","baseCheck":"","form":"M. l.poj.","alternation":"","note":"rodzaj żeński","fix":"","isPolish":true}]}"#
        let (app, _) = makeApp(replies: [messageReply(translation), messageReply(base)])
        let text = ReadingText(topic: "spacer", level: .b1, kind: .story, title: "Spacer",
                               paragraphs: ["Spacerowaliśmy nad rzeką… przy rzece było cicho."], keyWords: [])
        let reader = ReaderModel(text: text)
        let word = try XCTUnwrap(reader.document.paragraphs[0].tokens.first { $0.text == "rzece" })
        reader.translate(try XCTUnwrap(reader.tap(tokenID: word.id)), ai: app.ai, session: app.reading)
        await reader.waitForRequests()
        XCTAssertTrue(reader.canSaveBaseForm)
        XCTAssertEqual(reader.candidateCard()?.pl, "rzece")
        XCTAssertEqual(reader.candidateCard()?.alternation, "k→c")
        XCTAssertEqual(reader.candidateCard()?.note, "rzeka → rzece, Msc. l.poj., k→c")

        reader.saveBaseForm = true
        XCTAssertNil(reader.candidateCard(), "waits for the base form translation")
        reader.loadBaseForm(ai: app.ai)
        await reader.waitForRequests()
        let card = try XCTUnwrap(reader.candidateCard())
        XCTAssertEqual(card.pl, "rzeka")
        XCTAssertEqual(card.ru, "река")
        XCTAssertEqual(card.base, "")
        XCTAssertEqual(card.example, "Spacerowaliśmy nad rzeką… przy rzece było cicho.")
    }

    func testPhraseModeNeedsTwoTaps() throws {
        let text = ReadingText(topic: "t", level: .b1, kind: .opinion, title: "T",
                               paragraphs: ["Moim zdaniem, praca zdalna jest wygodna."], keyWords: [])
        let reader = ReaderModel(text: text)
        let words = reader.document.paragraphs[0].tokens.filter(\.isWord)
        reader.phraseMode = true
        XCTAssertNil(reader.tap(tokenID: words[0].id))
        XCTAssertEqual(reader.highlightedTokens, words[0].id...words[0].id)
        XCTAssertNil(reader.tap(tokenID: words[3].id))
        XCTAssertEqual(reader.pendingPhrase?.text, "Moim zdaniem, praca zdalna")
        XCTAssertEqual(reader.highlightedTokens, words[0].id...words[3].id)
        reader.phraseMode = false
        XCTAssertNil(reader.pendingPhrase)
        XCTAssertEqual(reader.tap(tokenID: words[2].id)?.text, "praca")
    }

    func testTranslationWithoutKeySaysItIsUnavailable() throws {
        let (app, _) = makeApp(replies: [], key: nil)
        let reader = ReaderModel(text: ReadingText(topic: "t", level: .a1, kind: .story, title: "T", paragraphs: ["Mam kota."], keyWords: []))
        let word = try XCTUnwrap(reader.document.paragraphs[0].tokens.first(where: \.isWord))
        reader.translate(try XCTUnwrap(reader.tap(tokenID: word.id)), ai: app.ai, session: app.reading)
        guard case .failed(let message, _) = reader.translation else { return XCTFail("expected a failure") }
        XCTAssertTrue(message.hasPrefix("Перевод недоступен"))
    }

    func testKnownWordsAreHighlightedByFormAndBase() {
        let reader = ReaderModel(text: ReadingText(topic: "t", level: .a2, kind: .story, title: "T",
                                                   paragraphs: ["Rzeka jest szeroka. Mieszkam przy rzece."], keyWords: []))
        reader.updateKnownWords([Flashcard(pl: "rzece", ru: "реке", base: "rzeka", source: .manual)].flatMap { [$0.pl, $0.base] })
        let known = reader.document.paragraphs[0].tokens.filter { reader.knownTokens.contains($0.id) }.map(\.text)
        XCTAssertEqual(known, ["Rzeka", "rzece"])
    }

    // MARK: Cards

    func testCheckScreenTranslatesPendingRowsAndRetries() async {
        let ok = #"{"items":[{"ru":"реке (дат./предл. п.)","base":"rzeka","baseCheck":"","form":"C./Msc. l.poj.","alternation":"k→c","note":"rzeka → rzece","fix":"","isPolish":true}]}"#
        let (app, transport) = makeApp(replies: [messageReply("not json"), messageReply(ok)])
        let drafts = OwnListParser.parse("rzece\nkot — кот").map { CardDraft(entry: $0, source: .list) }
        let review = DraftReviewModel(drafts: drafts, duplicates: 0, source: .list, wantBase: false)
        XCTAssertEqual(review.pendingCount, 1)

        await review.enrich(using: app.ai)
        XCTAssertEqual(review.failure, .invalidResponse)
        XCTAssertTrue(review.drafts[0].missingFromReply)

        review.drafts[1].ru = "кошка"
        await review.enrich(using: app.ai)
        XCTAssertNil(review.failure)
        XCTAssertEqual(review.drafts[0].ru, "реке (дат./предл. п.)")
        XCTAssertEqual(review.drafts[1].ru, "кошка", "edits made meanwhile stay")
        XCTAssertEqual(review.pendingCount, 0)
        let promptOfRetry = transport.lastBody?["messages"]?.arrayValue?.first?["content"]?.arrayValue?.last?["text"]?.stringValue ?? ""
        XCTAssertTrue(promptOfRetry.contains("1. rzece\n"))
        XCTAssertFalse(promptOfRetry.contains("kot"))
    }

    func testCheckScreenWithoutKey() async {
        let (app, transport) = makeApp(replies: [], key: nil)
        let review = DraftReviewModel(drafts: [CardDraft(entry: ParsedEntry(pl: "rzece"), source: .manual)], duplicates: 0, source: .manual, wantBase: true)
        await review.enrich(using: app.ai)
        XCTAssertEqual(review.failure, .notConfigured)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testStudySessionShowsAlternationAndKeepsMistakes() throws {
        // TZ 1, criterion 9.
        let card = Flashcard(pl: "rzece", ru: "реке (дат./предл. п.)", base: "rzeka", alternation: "k→c", source: .manual)
        let study = StudyModel(cards: [card])
        XCTAssertTrue(study.canHint)
        study.nextHint()
        XCTAssertEqual(study.baseHint, "rzeka")
        XCTAssertNil(study.lettersHint)
        study.nextHint()
        XCTAssertEqual(study.lettersHint, "r…")
        XCTAssertFalse(study.canHint)

        study.answer = "rzeka"
        let result = try XCTUnwrap(study.submit())
        XCTAssertEqual(study.check?.verdict, .wrong)
        XCTAssertEqual(result.card.box, 0)
        XCTAssertEqual(result.mistake?.types, [.ending])
        XCTAssertEqual(result.card.formLine, "rzeka → rzece (k→c)")

        study.next()
        XCTAssertEqual(study.current?.id, card.id, "a missed card comes back")
        study.answer = "rzece"
        let second = try XCTUnwrap(study.submit())
        XCTAssertEqual(study.check?.verdict, .correct)
        XCTAssertNil(second.mistake)
        XCTAssertEqual(second.card.box, 1)
        study.next()
        XCTAssertTrue(study.isFinished)
        XCTAssertEqual(study.summary.correct, 1)
        XCTAssertEqual(study.summary.wrong, 1)
    }

    func testDeletingCardsRemovesTheirMistakesAndUnusedPhotos() {
        let (app, _) = makeApp(replies: [])
        let photoID = app.photos.save([Data([0xFF, 0xD8])])!
        let first = Flashcard(pl: "rzece", ru: "реке", source: .photo, photoId: photoID)
        let second = Flashcard(pl: "morzu", ru: "морю", source: .photo, photoId: photoID)
        app.cards.add([first, second])
        app.mistakes.record(Mistake(cardId: first.id, check: AnswerChecker.check(given: "rzeka", expected: "rzece")))

        app.deleteCards(ids: [first.id])
        XCTAssertTrue(app.mistakes.mistakes.isEmpty)
        XCTAssertEqual(app.photos.photos(for: photoID).count, 1, "still used by the other card")
        app.deleteCards(ids: [second.id])
        XCTAssertTrue(app.photos.photos(for: photoID).isEmpty)
    }
}
