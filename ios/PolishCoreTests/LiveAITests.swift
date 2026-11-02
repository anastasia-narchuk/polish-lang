import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PolishCore

/// Live checks against the real Gemini API: the acceptance criteria that need a real model.
/// Skipped unless GEMINI_API_KEY is set, so CI and normal runs never call the API:
///
///     GEMINI_API_KEY=… swift test --filter LiveAITests/testName
///
/// Every test is one request of the free daily quota.
final class LiveAITests: XCTestCase {
    private func liveAI() throws -> PolishAI {
        guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty else {
            throw XCTSkip("GEMINI_API_KEY is not set")
        }
        let model = ProcessInfo.processInfo.environment["GEMINI_MODEL"] ?? GeminiClient.defaultModel
        return PolishAI(client: GeminiClient(), config: geminiConfig(model: model).with(apiKey: key))
    }

    /// TZ 1, criteria 1–5.
    func testEnrichForms() async throws {
        let ai = try liveAI()
        let outcome = await ai.enrich([
            EnrichInput(pl: "rzece"),
            EnrichInput(pl: "o morzu"),
            EnrichInput(pl: "poszłam", base: "pójść"),
            EnrichInput(pl: "poszłam", base: "iść"),
            EnrichInput(pl: "ksiazce"),
        ])
        XCTAssertNil(outcome.failure)
        let results = outcome.results.map { $0 ?? EnrichResult() }
        for (index, result) in results.enumerated() {
            print("LIVE enrich \(index + 1):", result)
        }
        XCTAssertEqual(results[0].base, "rzeka")
        XCTAssertEqual(results[0].alternation, "k→c")
        XCTAssertEqual(results[1].base, "morze")
        XCTAssertTrue(results[2].baseCheck.isEmpty)
        XCTAssertFalse(results[3].baseCheck.isEmpty)
        XCTAssertEqual(results[4].fix, "książce")
    }

    /// TZ 2, criterion 1: A1 is 60–90 words in the present tense.
    func testGenerateA1() async throws {
        let ai = try liveAI()
        let text = try await ai.generate(topic: "wizyta u lekarza", kind: .story, level: .a1, myWords: [])
        let check = GenerationValidator.check(text, level: .a1)
        print("LIVE A1 (\(check.wordCount) words):", text.title, text.paragraphs.joined(separator: "\n"))
        XCTAssertNil(check.lengthWarning)
        XCTAssertFalse(check.hasCyrillic)
    }

    /// TZ 2, criterion 5.
    func testTranslateInContext() async throws {
        let ai = try liveAI()
        let translation = try await ai.translate(selection: "lekarza", sentence: "W zeszłym tygodniu musiałam pójść do lekarza, ponieważ bolało mnie gardło.", title: "Wizyta u lekarza")
        print("LIVE translate:", translation)
        XCTAssertEqual(translation.base, "lekarz")
        XCTAssertTrue(translation.alternation.isEmpty)
    }
}

extension LiveAITests {
    /// TZ 3, 7.1: a B1 exam task with points, plan, connectors and ideas.
    func testWritingTask() async throws {
        let ai = try liveAI()
        let prompt = WritingPrompts.task(level: .b1, form: WritingForm.complaint.promptName, topic: "zakupy", words: "około 150", must: [], mustConnectors: [])
        let task = try await ai.writingTask(prompt: prompt)
        print("LIVE task:", task.form, "|", task.register, "|", task.polecenie, "|", task.punkty, "|", task.plan.map(\.ru), "|", task.connectors, "|", task.ideas.map { "\($0.ru) → \($0.pl)" })
        XCTAssertTrue((3...4).contains(task.punkty.count))
        XCTAssertTrue((3...4).contains(task.plan.count))
        XCTAssertTrue((4...6).contains(task.connectors.count))
        XCTAssertTrue((5...6).contains(task.ideas.count))
        XCTAssertFalse(PolishText.containsCyrillic(task.polecenie))
    }

    /// TZ 3, criteria 4 and 5: a letter that misses a point and mixes "Szanowny Panie" with "jak się masz?".
    func testCheckFindsMissedPointAndMixedRegister() async throws {
        let ai = try liveAI()
        let task = WritingTask(
            form: "reklamacja", register: "formalny",
            polecenie: "Kupiłaś w sklepie internetowym ekspres do kawy, który po tygodniu przestał działać. Napisz reklamację do sklepu.",
            punkty: ["Napisz, co i kiedy kupiłaś.", "Opisz, co się zepsuło.", "Napisz, czego oczekujesz od sklepu."],
            words: 150, ru: "", plan: [], connectors: [], ideas: [], level: .b1, kind: .complaint, length: .long
        )
        let text = """
        Szanowny Panie,
        piszę do Pana, bo 3 października kupiłam w Waszym sklepie ekspres do kawy marki Kawex. Jak się masz? Niestety po tygodniu ekspres przestał działać: nie grzeje wody i nie robi kawy. Bardzo mnie to zdenerwowało, bo to był prezent dla mojej mamy. Ekspres był drogi i myślałam, że będzie dobrej jakości. Mam nadzieję, że szybko mi Pan odpowie.
        Pozdrawiam, Anna Nowak
        """
        let raw = try await ai.checkText(task: task, text: text)
        print("LIVE check raw points:", raw.points.map { "\($0.status.rawValue): \($0.punkt)" })
        print("LIVE check raw register:", raw.register, "scores:", raw.scores, "percent:", raw.scores.percent)
        print("LIVE check errors:", raw.errors.map { "\($0.fragment) → \($0.correction) [\($0.type)] \($0.ruleRu)" })
        print("LIVE check summary:", raw.summaryRu, "| new words:", raw.newWords.map(\.pl), "| upgrade:", raw.upgrade.map(\.better))
        let guarded = WritingRules.applyGuards(raw, text: text)
        XCTAssertEqual(guarded.points.last?.status, .no, "the expectation point is missing")
        XCTAssertLessThanOrEqual(guarded.scores.zadanie, 3)
        XCTAssertFalse(guarded.register.consistent)
        let ranges = WritingRules.errorRanges(in: text, errors: raw.errors)
        print("LIVE fragments found in the text: \(ranges.count) of \(raw.errors.count)")
    }
}

extension AIConfiguration {
    func with(apiKey: String) -> AIConfiguration {
        var copy = self
        copy.apiKey = apiKey
        return copy
    }
}
