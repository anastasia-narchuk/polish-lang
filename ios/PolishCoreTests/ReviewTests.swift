import XCTest
@testable import PolishCore

/// TZ 1, section 6: how a card works in review.
final class ReviewTests: XCTestCase {
    func testExactAnswerIsCorrect() {
        let check = AnswerChecker.check(given: "  Rzece ", expected: "rzece")
        XCTAssertEqual(check.verdict, .correct)
        XCTAssertTrue(check.errorTypes.isEmpty)
    }

    func testMissingOgonkiIsAlmost() {
        let check = AnswerChecker.check(given: "ksiazce", expected: "książce")
        XCTAssertEqual(check.verdict, .almost)
        XCTAssertEqual(check.errorTypes, [.ogonki])
    }

    func testOneLetterInLongWordIsAlmostButNotInShortWord() {
        XCTAssertEqual(AnswerChecker.check(given: "mieszkanu", expected: "mieszkaniu").verdict, .almost)
        XCTAssertEqual(AnswerChecker.check(given: "rzeca", expected: "rzece").verdict, .wrong, "the ending is the point of the card")
    }

    func testDifferentWordIsWrong() {
        let check = AnswerChecker.check(given: "dom", expected: "rzece")
        XCTAssertEqual(check.verdict, .wrong)
        XCTAssertEqual(check.errorTypes, [.other])
        XCTAssertEqual(AnswerChecker.check(given: "", expected: "rzece").verdict, .wrong)
    }

    func testErrorTypes() {
        XCTAssertEqual(AnswerChecker.check(given: "gura", expected: "góra").errorTypes, [.uO])
        XCTAssertEqual(AnswerChecker.check(given: "żeka", expected: "rzeka").errorTypes, [.rzZ])
        XCTAssertEqual(AnswerChecker.check(given: "zeka", expected: "rzeka").errorTypes, [.rzZ, .ogonki])
        XCTAssertEqual(AnswerChecker.check(given: "hleb", expected: "chleb").errorTypes, [.chH])
        XCTAssertEqual(AnswerChecker.check(given: "idę", expected: "idą").errorTypes, [.nasal])
        XCTAssertEqual(AnswerChecker.check(given: "rzeka", expected: "rzece").errorTypes, [.ending])
    }

    func testLetterDiff() {
        let check = AnswerChecker.check(given: "rzeca", expected: "rzece")
        XCTAssertEqual(check.diff, [.same("r"), .same("z"), .same("e"), .same("c"), .substitute(expected: "e", given: "a")])
        let missing = AnswerChecker.check(given: "ksizce", expected: "książce")
        XCTAssertEqual(missing.diff.filter { !$0.isSame }, [.missing("ą"), .substitute(expected: "ż", given: "z")])
        XCTAssertEqual(missing.diff.count, 7)
    }

    func testLeitnerBoxes() {
        let now = Date()
        var card = Flashcard(pl: "rzece", ru: "реке", source: .manual, created: now)
        XCTAssertEqual(card.box, 0)

        Leitner.apply(.good, mistake: false, to: &card, now: now)
        XCTAssertEqual(card.box, 1)
        XCTAssertEqual(card.due.timeIntervalSince(now), 86_400, accuracy: 1)
        Leitner.apply(.good, mistake: false, to: &card, now: now)
        Leitner.apply(.good, mistake: false, to: &card, now: now)
        XCTAssertEqual(card.box, 3)

        Leitner.apply(.hard, mistake: true, to: &card, now: now)
        XCTAssertEqual(card.box, 2)
        Leitner.apply(.again, mistake: true, to: &card, now: now)
        XCTAssertEqual(card.box, 0)
        XCTAssertEqual(card.due, now)
        XCTAssertEqual(card.right, 3)
        XCTAssertEqual(card.wrong, 2)
    }

    func testHintLowersTheGrade() {
        XCTAssertEqual(Leitner.grade(verdict: .correct, usedHint: false, revealed: false), .good)
        XCTAssertEqual(Leitner.grade(verdict: .correct, usedHint: true, revealed: false), .hard)
        XCTAssertEqual(Leitner.grade(verdict: .almost, usedHint: false, revealed: false), .hard)
        XCTAssertEqual(Leitner.grade(verdict: .correct, usedHint: false, revealed: true), .again)
    }

    func testDueCardsAndQueue() {
        let now = Date()
        var later = Flashcard(pl: "b", ru: "б", source: .manual, created: now)
        later.due = now.addingTimeInterval(3600)
        let a = Flashcard(pl: "a", ru: "а", source: .manual, created: now.addingTimeInterval(-10))
        let c = Flashcard(pl: "c", ru: "в", source: .manual, created: now.addingTimeInterval(-5))
        let due = StudyPlanner.dueCards([later, c, a], now: now, limit: 10)
        XCTAssertEqual(due.map(\.pl), ["a", "c"])
        XCTAssertEqual(StudyPlanner.nextDueDate([later, a], now: now), later.due)

        var queue = StudyQueue(cardIDs: ["1", "2", "3", "4", "5"])
        queue.advance(repeatCard: true)
        XCTAssertEqual(queue.pending, ["2", "3", "4", "1", "5"])
        queue.advance(repeatCard: false)
        XCTAssertEqual(queue.finished, 1)
        XCTAssertEqual(queue.remaining, 4)
    }

    func testMissedCardReturnsAtMostTwice() {
        var queue = StudyQueue(cardIDs: ["1"])
        queue.advance(repeatCard: true)
        queue.advance(repeatCard: true)
        XCTAssertEqual(queue.pending, ["1"])
        queue.advance(repeatCard: true)
        XCTAssertTrue(queue.isEmpty)
    }

    func testMistakeKeepsTypes() {
        let check = AnswerChecker.check(given: "żeka", expected: "rzeka")
        let mistake = Mistake(cardId: "rzeka-1", check: check)
        XCTAssertEqual(mistake.types, [.rzZ])
        XCTAssertEqual(mistake.verdict, .wrong)
    }
}
