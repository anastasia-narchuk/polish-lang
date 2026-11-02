import XCTest
@testable import PolishCore

/// The writing module (TZ 3) with a fake Claude API: tasks, the workspace, the check and the ladder.
@MainActor
final class WritingTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("polish-writing-tests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeApp(replies: [MockTransport.Reply], key: String? = "sk-ant-test") -> (AppModel, MockTransport) {
        let secrets = InMemorySecretStore()
        if let key { secrets.save(key, account: "anthropic-api-key") }
        let app = AppModel(directory: directory, secrets: secrets, defaults: UserDefaults(suiteName: "polish-writing-\(UUID().uuidString)")!)
        let transport = MockTransport(replies)
        app.ai.client = AnthropicClient(transport: transport)
        return (app, transport)
    }

    private static func prompt(_ transport: MockTransport, _ index: Int) -> String {
        guard transport.requests.indices.contains(index), let body = transport.requests[index].httpBody.flatMap(JSONValue.decode) else { return "" }
        return body["messages"]?.arrayValue?.first?["content"]?.arrayValue?.last?["text"]?.stringValue ?? ""
    }

    static let taskJSON = #"{"task":{"form":"e-mail do koleżanki","register":"nieformalny","polecenie":"Napisz e-mail do koleżanki o przeprowadzce do nowego mieszkania.","punkty":["Opisz nowe mieszkanie.","Zaproś koleżankę w odwiedziny.","Zapytaj o jej plany na weekend."],"words":"140","ru":"Напиши подруге о переезде.","plan":[{"ru":"Приветствие","phrases":["Cześć Kasiu,","Co słychać?"]},{"ru":"Квартира","phrases":["Mieszkam teraz w…"]},{"ru":"Прощание","phrases":["Pozdrawiam serdecznie"]}],"connectors":["poza tym","dlatego","jednak","na przykład"],"ideas":[{"ru":"светлая кухня","pl":"jasna kuchnia"},{"ru":"близко к работе","pl":"blisko pracy"},{"ru":"приходи в субботу","pl":"wpadnij w sobotę"}]}}"#

    static func checkJSON(points: String = #"[{"punkt":"Opisz nowe mieszkanie.","status":"tak","quote":"Mam jasna kuchnie"},{"punkt":"Zaproś koleżankę w odwiedziny.","status":"nie","quote":""},{"punkt":"Zapytaj o jej plany na weekend.","status":"częściowo","quote":"A ty?"}]"#, consistent: Bool = true) -> String {
        #"{"errors":[{"fragment":"jasna kuchnie","correction":"jasną kuchnię","type":"ortografia","rule_ru":"Вин. п. ж. р.: -ą, -ę."},{"fragment":"nie ma w tekście","correction":"x","type":"gramatyka","rule_ru":"—"}],"points":"# + points + #","register":{"expected":"nieformalny","detected":"nieformalny","consistent":"# + (consistent ? "true" : "false") + #","issues_ru":[]},"scores":{"zadanie":5,"spojnosc":"4","gramatyka":3,"leksyka":4,"ortografia":9},"corrected_text":"Cześć Kasiu! Mam jasną kuchnię.","upgrade":[{"plain":"Mam jasna kuchnie","better":"Moja kuchnia jest przestronna i jasna","ru":"богаче лексика"}],"new_words":[{"pl":"w odwiedziny","base":"odwiedziny","ru":"в гости"},{"pl":"parapetówkę","base":"parapetówka","ru":"новоселье (вин. п.)"}],"used":[],"summary_ru":"Хорошее начало, но пропущено приглашение."}"#
    }

    private static let typedText = "Cześć Kasiu! Mam nowe mieszkanie. Mam jasna kuchnie i duży pokój. A ty? Co robisz w weekend? Pozdrawiam serdecznie."

    // MARK: Prompts and parsing

    func testTaskPromptsFollowTheStep() {
        let akapit = WritingPrompts.task(level: .b1, form: WritingPrompts.akapitForms, topic: "", words: "50–80", must: ["rzeka", "lekarz"], mustConnectors: ["dlatego", "jednak"])
        XCTAssertTrue(akapit.contains("poziom B1"))
        XCTAssertTrue(akapit.contains("Liczba słów: 50–80."))
        XCTAssertTrue(akapit.contains("W zadaniu musi dać się naturalnie użyć słów: rzeka, lekarz, oraz wyrażeń: dlatego, jednak."))
        XCTAssertTrue(akapit.contains("z życia codziennego w Polsce"))
        let exam = WritingPrompts.task(level: .b2, form: "reklamacja", topic: "praca", words: "około 250", must: [], mustConnectors: [])
        XCTAssertTrue(exam.contains("Forma: reklamacja. Temat: praca. Liczba słów: około 250."))
        XCTAssertFalse(exam.contains("musi dać się"))
        let check = WritingPrompts.check(task: try! WritingParser.task(from: Self.taskJSON), text: Self.typedText)
        XCTAssertTrue(check.contains("Punkty: Opisz nowe mieszkanie.; Zaproś koleżankę w odwiedziny.; Zapytaj o jej plany na weekend.."))
        XCTAssertTrue(check.contains("\"points\""))
        XCTAssertTrue(check.contains("\"register\""))
        XCTAssertTrue(check.contains("(tekst ma \(PolishText.wordCount(Self.typedText)))"))
    }

    func testParsersAreTolerant() throws {
        let task = try WritingParser.task(from: "```json\n" + Self.taskJSON + "\n```")
        XCTAssertEqual(task.words, 140, "a number as text is read")
        XCTAssertEqual(task.plan.count, 3)
        XCTAssertEqual(task.ideas.map(\.pl), ["jasna kuchnia", "blisko pracy", "wpadnij w sobotę"])
        XCTAssertFalse(task.isFormal)
        XCTAssertThrowsError(try WritingParser.task(from: #"{"task":{"polecenie":""}}"#)) { XCTAssertEqual($0 as? AIError, .refusal) }

        let check = try WritingParser.check(from: Self.checkJSON())
        XCTAssertEqual(check.scores.spojnosc, 4)
        XCTAssertEqual(check.scores.ortografia, 5, "scores are clamped to 0–5")
        XCTAssertEqual(check.points.map(\.status), [.yes, .no, .partly])
        XCTAssertEqual(check.points.map(\.status.mark), ["✓", "✗", "≈"])
        XCTAssertEqual(check.newWords.first?.pl, "w odwiedziny")
        XCTAssertEqual(check.scores.percent, Int((21.0 / 25 * 100).rounded()))
    }

    // MARK: The support (TZ 3, section 5)

    func testVisibilityTable() {
        let akapit = SupportPolicy.of(mode: .akapit, hand: false)
        XCTAssertEqual(akapit.plan, .open)
        XCTAssertEqual(akapit.ideas, .open)
        XCTAssertTrue(akapit.lettersBar)
        XCTAssertEqual(akapit.timer, .none)
        XCTAssertFalse(SupportPolicy.of(mode: .akapit, hand: true).lettersBar)
        let exam = SupportPolicy.of(mode: .exam, hand: true)
        XCTAssertEqual(exam.plan, .hidden)
        XCTAssertEqual(exam.connectors, .hidden)
        XCTAssertEqual(exam.ideas, .hidden)
        XCTAssertEqual(exam.traps, .open)
        XCTAssertTrue(exam.translationAvailable)
        XCTAssertFalse(exam.lettersBar)
        XCTAssertEqual(exam.timer, .stopwatch)
        let simulation = SupportPolicy.of(mode: .exam, hand: true, simulation: true)
        XCTAssertEqual(simulation.plan, .unavailable)
        XCTAssertFalse(simulation.translationAvailable)
        XCTAssertEqual(simulation.timer, .countdown)
    }

    func testAkapitSupportIsOpenAndIdeasAreCounted() async {
        // TZ 3, criterion 1.
        let (app, transport) = makeApp(replies: [messageReply(Self.taskJSON)])
        app.cards.add([Flashcard(pl: "rzece", ru: "реке", base: "rzeka", source: .list)])
        app.writing.start(.today)
        await app.writing.waitForGeneration()
        let workspace = try! XCTUnwrap(app.writing.workspace)

        XCTAssertEqual(app.writing.path, [.workspace])
        XCTAssertEqual(workspace.mode, .akapit)
        XCTAssertTrue(workspace.supportShown)
        XCTAssertFalse(workspace.hand)
        XCTAssertTrue(workspace.lettersBarShown)
        XCTAssertEqual(workspace.task.must, ["rzeka"])
        XCTAssertEqual(workspace.task.mustConnectors.count, 2)
        XCTAssertEqual(workspace.range, 50...80)
        XCTAssertTrue(workspace.revealedIdeas.isEmpty, "ideas start with the Russian thought only")
        workspace.revealIdea(1)
        workspace.revealIdea(1)
        workspace.revealIdea(2)
        XCTAssertEqual(workspace.support.ideasRevealed, 2)
        XCTAssertEqual(workspace.support.ideasTotal, 3)
        XCTAssertTrue(Self.prompt(transport, 0).contains("rzeka"))
    }

    func testExamTrainingHidesTheSupportAndOpeningMarksTheText() async {
        // TZ 3, criterion 2.
        let (app, _) = makeApp(replies: [messageReply(Self.taskJSON), messageReply(Self.checkJSON())])
        app.writing.start(.form(.email, topic: "mieszkanie"))
        await app.writing.waitForGeneration()
        let workspace = try! XCTUnwrap(app.writing.workspace)
        XCTAssertEqual(workspace.mode, .exam)
        XCTAssertFalse(workspace.supportShown)
        XCTAssertFalse(workspace.support.opened)
        XCTAssertTrue(workspace.hand, "exam tasks are written by hand by default")
        XCTAssertFalse(workspace.lettersBarShown)

        workspace.toggleSupport()
        XCTAssertTrue(workspace.support.opened)
        workspace.hand = false
        workspace.text = Self.typedText
        workspace.check()
        await workspace.waitForWork()
        let saved = try! XCTUnwrap(app.writingTexts.texts.first)
        XCTAssertTrue(saved.support.opened, "the history marks it «с опорой»")

        // Three exam texts by hand: the one with support stays out of the forecast.
        var clean = saved
        clean.hand = true
        clean.support.opened = false
        clean.score = 60
        var withSupport = clean
        withSupport.support.opened = true
        withSupport.score = 100
        XCTAssertNil(WritingRules.forecast([clean, withSupport, clean]), "only 2 texts count")
        XCTAssertEqual(WritingRules.forecast([clean, withSupport, clean, clean]), 18)
    }

    // MARK: The check

    func testMissedPointCapsTheTaskScoreAndErrorsGoToTheBank() async {
        // TZ 3, criterion 4.
        let (app, transport) = makeApp(replies: [messageReply(Self.taskJSON), messageReply(Self.checkJSON())])
        app.writing.start(.form(.email, topic: ""))
        await app.writing.waitForGeneration()
        let workspace = try! XCTUnwrap(app.writing.workspace)
        workspace.hand = false
        workspace.text = "Za krótko"
        XCTAssertFalse(workspace.canCheck, "fewer than 5 words")
        workspace.text = Self.typedText
        XCTAssertTrue(workspace.canCheck)
        workspace.check()
        await workspace.waitForWork()

        let saved = try! XCTUnwrap(workspace.result)
        XCTAssertEqual(saved.result.points[1].status, .no)
        XCTAssertEqual(saved.result.scores.zadanie, 3, "5 from the model, capped by the missed point")
        XCTAssertEqual(saved.score, Int((Double(3 + 4 + 3 + 4 + 5) / 25 * 100).rounded()))
        XCTAssertEqual(saved.taskWeight, 10, "e-mail is a short form: 10 points by default")
        XCTAssertEqual(saved.taskPoints, WritingRules.taskPoints(percent: saved.score, weight: 10))
        XCTAssertEqual(app.writing.path, [.feedback(saved.id)])
        XCTAssertEqual(app.textErrors.entries.first { $0.fragment == "jasna kuchnie" }?.cat, "ogonki")
        XCTAssertTrue(Self.prompt(transport, 1).contains(Self.typedText))
        let ranges = WritingRules.errorRanges(in: saved.text, errors: saved.result.errors)
        XCTAssertNotNil(ranges[0])
        XCTAssertNil(ranges[1], "a fragment that is not in the text is listed without an underline")
    }

    func testMixedSalutationsMakeTheRegisterInconsistent() throws {
        // TZ 3, criterion 5: the model said "consistent", the guard disagrees.
        let text = "Szanowny Panie, piszę w sprawie mieszkania. Jak się masz? Z poważaniem, Anna"
        let check = WritingRules.applyGuards(try WritingParser.check(from: Self.checkJSON(consistent: true)), text: text)
        XCTAssertFalse(check.register.consistent)
        let issue = try XCTUnwrap(check.register.issuesRu.last)
        XCTAssertTrue(issue.contains("szanowny") && issue.contains("jak się masz"), issue)
        XCTAssertTrue(PolishText.containsCyrillic(issue))
        XCTAssertTrue(WritingRules.applyGuards(try WritingParser.check(from: Self.checkJSON()), text: "Cześć! Jak się masz?").register.consistent)
    }

    func testHandwrittenTextIsTranscribedConfirmedThenChecked() async {
        let (app, transport) = makeApp(replies: [messageReply(Self.taskJSON), messageReply("Cześć Kasiu! Mam nowe [?] mieszkanie. Mam jasna kuchnie."), messageReply(Self.checkJSON())])
        app.writing.start(.today)
        app.settings.writingStep = .egzamin
        await app.writing.waitForGeneration()
        let workspace = try! XCTUnwrap(app.writing.workspace)
        XCTAssertFalse(workspace.canCheck, "no photos yet")
        workspace.addPhotos([Data([0xFF, 0xD8, 1]), Data([0xFF, 0xD8, 2])])
        workspace.movePhoto(from: 1, by: -1)
        XCTAssertEqual(workspace.photos.first, Data([0xFF, 0xD8, 2]))
        workspace.check()
        await workspace.waitForWork()
        XCTAssertEqual(workspace.phase, .reviewingTranscript)
        XCTAssertEqual(workspace.unreadableShare, 1.0 / 9, accuracy: 0.001)
        XCTAssertEqual(transport.requests[1].httpBody.flatMap(JSONValue.decode)?["messages"]?.arrayValue?.first?["content"]?.arrayValue?.count, 3, "two photos and the prompt")

        workspace.transcript = "Cześć Kasiu! Mam nowe mieszkanie. Mam jasna kuchnie."
        workspace.check()
        await workspace.waitForWork()
        let saved = try! XCTUnwrap(workspace.result)
        XCTAssertTrue(saved.hand)
        XCTAssertEqual(saved.text, "Cześć Kasiu! Mam nowe mieszkanie. Mam jasna kuchnie.")
        XCTAssertNotNil(saved.photoId)
        XCTAssertEqual(app.photos.photos(for: saved.photoId!).count, 2)
    }

    func testCheckFailureKeepsTheDraftAndOffersRetry() async {
        let (app, _) = makeApp(replies: [messageReply(Self.taskJSON), MockTransport.Reply(status: 529, body: "{}"), messageReply(Self.checkJSON())])
        app.writing.start(.today)
        await app.writing.waitForGeneration()
        let workspace = try! XCTUnwrap(app.writing.workspace)
        workspace.text = Self.typedText
        workspace.check()
        await workspace.waitForWork()
        guard case .failed(_, let canRetry) = workspace.phase else { return XCTFail("expected a failure") }
        XCTAssertTrue(canRetry)
        XCTAssertEqual(app.writing.unsavedDraft?.text, Self.typedText)
        workspace.retry()
        await workspace.waitForWork()
        XCTAssertNotNil(workspace.result)
    }

    // MARK: Cards and settings

    func testNewWordsKeepTheirFormInCards() throws {
        // TZ 3, criterion 9.
        let (app, _) = makeApp(replies: [])
        let words = try WritingParser.check(from: Self.checkJSON()).newWords
        let result = app.writing.addToCards(words)
        XCTAssertEqual(result.cards.map(\.pl), ["w odwiedziny", "parapetówkę"])
        XCTAssertEqual(app.cards.cards.first { $0.pl == "parapetówkę" }?.base, "parapetówka")
        XCTAssertEqual(app.cards.cards.first?.source, .writing)
        XCTAssertEqual(app.writing.addToCards(words).cards.count, 0, "the same forms are not added twice")
    }

    func testSettingsApplyToTheNextTask() async {
        // TZ 3, criterion 10.
        let (app, transport) = makeApp(replies: [messageReply(Self.taskJSON), messageReply(Self.taskJSON), messageReply(Self.taskJSON)])
        app.settings.writing.wordsB1.long = 180
        app.writing.start(.form(.formalLetter, topic: ""))
        await app.writing.waitForGeneration()
        XCTAssertEqual(app.writing.workspace?.task.words, 180)
        XCTAssertTrue(Self.prompt(transport, 0).contains("około 180"))

        app.settings.writing.examLevel = .b2
        app.settings.writing.wordsB2.short = 130
        app.writing.discardDraft()
        app.writing.start(.form(.announcement, topic: ""))
        await app.writing.waitForGeneration()
        XCTAssertEqual(app.writing.workspace?.task.words, 130)
        XCTAssertEqual(app.writing.workspace?.task.level, .b2)
        XCTAssertTrue(Self.prompt(transport, 1).contains("poziom B2"))

        // The Egzamin step alternates the short and the long form.
        app.writing.choose(.egzamin)
        app.settings.nextExamLength = .long
        app.writing.discardDraft()
        app.writing.start(.today)
        await app.writing.waitForGeneration()
        XCTAssertEqual(app.writing.workspace?.task.length, .long)
        XCTAssertEqual(app.settings.nextExamLength, .short)
    }

    // MARK: Drafts and the ladder

    func testDraftSurvivesALaunchAndANewStartAsksFirst() async {
        let (app, transport) = makeApp(replies: [messageReply(Self.taskJSON), messageReply(Self.taskJSON)])
        app.writing.start(.today)
        await app.writing.waitForGeneration()
        app.writing.workspace?.text = "Mój szkic"
        app.writing.workspace?.saveDraftNow()

        let again = AppModel(directory: directory, secrets: InMemorySecretStore(), defaults: UserDefaults(suiteName: "polish-writing-\(UUID().uuidString)")!)
        XCTAssertEqual(again.writing.savedDraft?.text, "Mój szkic")

        app.writing.start(.form(.wishes, topic: ""))
        XCTAssertEqual(app.writing.pendingStart, .form(.wishes, topic: ""), "the draft has text: ask before replacing it")
        XCTAssertEqual(transport.requests.count, 1)
        app.writing.confirmPendingStart()
        await app.writing.waitForGeneration()
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(app.writing.workspace?.text, "")
    }

    func testEgzaminOpensAfterThreeGoodParagraphsTwoByHand() {
        func text(score: Int, hand: Bool) -> WritingText {
            let check = try! WritingParser.check(from: Self.checkJSON())
            return WritingText(id: UUID().uuidString, created: Date(), mode: .akapit, step: .akapit, examLevel: .b1,
                               task: try! WritingParser.task(from: Self.taskJSON), ideasDraft: "", text: "x", hand: hand, photoId: nil,
                               seconds: 60, support: SupportStats(), checklist: WritingChecklist(), result: check, score: score,
                               taskPoints: nil, taskWeight: nil)
        }
        XCTAssertFalse(WritingRules.akapitProgress([text(score: 80, hand: false), text(score: 90, hand: false), text(score: 75, hand: true)]).met)
        XCTAssertFalse(WritingRules.akapitProgress([text(score: 80, hand: true), text(score: 60, hand: true), text(score: 75, hand: false)]).met)
        let met = WritingRules.akapitProgress([text(score: 80, hand: true), text(score: 70, hand: true), text(score: 75, hand: false)])
        XCTAssertTrue(met.met)
        XCTAssertEqual(met.fraction, 1)
    }

    // MARK: Small rules

    func testRequiredWordsAreMatchedByStem() {
        XCTAssertTrue(WritingRules.isUsed("rzeka", in: "Spacerowałam przy rzece."))
        XCTAssertTrue(WritingRules.isUsed("lekarz", in: "Poszłam do lekarza."))
        XCTAssertTrue(WritingRules.isUsed("wydaje mi się, że", in: "Wydaje mi się, że to dobry pomysł."))
        XCTAssertFalse(WritingRules.isUsed("dlatego", in: "Nie wiem, dlaczego."))
        XCTAssertFalse(WritingRules.isUsed("po pierwsze", in: "Pierwsze wrażenie."))
    }

    func testLengthStatus() {
        let range = 135...165
        XCTAssertEqual(WritingRules.lengthStatus(count: 150, range: range), .ok)
        XCTAssertEqual(WritingRules.lengthStatus(count: 120, range: range), .near)
        XCTAssertEqual(WritingRules.lengthStatus(count: 195, range: range), .near)
        XCTAssertEqual(WritingRules.lengthStatus(count: 90, range: range), .far)
        let task = try! WritingParser.task(from: Self.taskJSON)
        XCTAssertEqual(WritingRules.range(for: task, mode: .exam), 126...154)
        XCTAssertEqual(WritingRules.range(for: task, mode: .akapit), 50...80)
    }

    func testSpellingCategoriesAndTraps() {
        XCTAssertEqual(WritingRules.spellingCategory(fragment: "moze", correction: "może"), "ogonki")
        XCTAssertEqual(WritingRules.spellingCategory(fragment: "żeka", correction: "rzeka"), "rz/ż")
        XCTAssertEqual(WritingRules.spellingCategory(fragment: "kturzy", correction: "którzy"), "ó/u")
        XCTAssertEqual(WritingRules.spellingCategory(fragment: "nie dużo", correction: "niedużo"), "nie")

        let (app, _) = makeApp(replies: [])
        let check = try! WritingParser.check(from: Self.checkJSON(consistent: false))
        let old = Date().addingTimeInterval(-10 * 86_400)
        app.textErrors.record(check, source: "exam", now: old)
        app.textErrors.record(check, source: "exam", now: old)
        app.textErrors.record(TextCheck(errors: [TextError(fragment: "żeka", correction: "rzeka", type: "ortografia", ruleRu: "")], points: [],
                                        register: RegisterCheck(expected: "", detected: "", consistent: true, issuesRu: []),
                                        scores: CriteriaScores(zadanie: 0, spojnosc: 0, gramatyka: 0, leksyka: 0, ortografia: 0),
                                        correctedText: "", upgrade: [], newWords: [], used: [], summaryRu: ""), source: "akapit")
        let traps = app.textErrors.traps()
        XCTAssertEqual(traps.count, 3)
        XCTAssertEqual(traps.first?.trapLine, "rz/ż: żeka → rzeka", "count 1 today beats count 2 ten days ago")
        XCTAssertTrue(traps.contains { $0.trapLine == "Pan/Pani или ty — не смешивай" })
        XCTAssertEqual(app.textErrors.entries.first { $0.fragment == "jasna kuchnie" }?.count, 2)
    }
}
