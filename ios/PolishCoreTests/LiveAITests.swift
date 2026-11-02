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

extension AIConfiguration {
    func with(apiKey: String) -> AIConfiguration {
        var copy = self
        copy.apiKey = apiKey
        return copy
    }
}
