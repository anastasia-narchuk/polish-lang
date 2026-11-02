#if DEBUG
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftUI

/// Debug builds only: sample data and a fake Claude that answers from fixtures, for screenshots
/// and for trying the app without a network or an API key.
///
///     -demo                    sample data in a temporary folder, fake AI
///     -demo-screen <name>      setup, reader, panel, cards, add, review, study, settings, writing
enum DemoMode {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isOn: Bool {
        arguments.contains("-demo")
    }

    static var screen: String? {
        guard isOn, let index = arguments.firstIndex(of: "-demo-screen"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// The reader taps this word by itself on the "panel" screen.
    static var autoTapWord: String? {
        screen == "panel" ? "lekarza" : nil
    }


    @MainActor
    static func makeApp() -> AppModel {
        let id = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("demo-\(id)", isDirectory: true)
        let secrets = InMemorySecretStore()
        secrets.save("demo", account: "anthropic-api-key")
        let app = AppModel(directory: directory, secrets: secrets, defaults: UserDefaults(suiteName: "demo-\(id)") ?? .standard)
        app.ai.client = AnthropicClient(transport: DemoTransport())
        app.cards.add(sampleCards(now: Date()))
        for mistake in sampleMistakes() { app.mistakes.record(mistake) }
        app.readings.save(sampleText)
        app.reading.topic = "wizyta u lekarza"
        switch screen {
        case "cards":
            app.tab = .cards
        case "settings":
            app.tab = .settings
        case "writing":
            app.tab = .writing
        default:
            break
        }
        return app
    }

    static let sampleText = ReadingText(
        id: "demo-text",
        topic: "wizyta u lekarza",
        level: .b1,
        kind: .story,
        title: "Wizyta u lekarza",
        paragraphs: [
            "W zeszłym tygodniu musiałam pójść do lekarza, ponieważ od kilku dni bolało mnie gardło. Zapisałam się na wizytę przez internet, co okazało się bardzo wygodne.",
            "Lekarz był miły i cierpliwy. Zapytał, jak długo mam objawy i czy biorę jakieś leki. Moim zdaniem takie rozmowy są ważne, bo pacjent czuje się bezpieczniej.",
            "Na koniec dostałam receptę i zwolnienie na trzy dni. Wieczorem spacerowałam jeszcze nad rzeką… przy rzece było cicho i spokojnie.",
        ],
        keyWords: [
            KeyWord(form: "do lekarza", base: "lekarz", ru: "к врачу"),
            KeyWord(form: "objawy", base: "objaw", ru: "симптомы"),
            KeyWord(form: "Moim zdaniem", base: "moim zdaniem", ru: "по-моему"),
            KeyWord(form: "receptę", base: "recepta", ru: "рецепт (вин. п.)"),
            KeyWord(form: "zwolnienie", base: "zwolnienie", ru: "больничный"),
        ],
        usedMyWords: ["rzece"]
    )

    static func sampleCards(now: Date) -> [Flashcard] {
        var cards = [
            Flashcard(pl: "rzece", ru: "реке (дат./предл. п.)", base: "rzeka", form: "C./Msc. l.poj.", alternation: "k→c",
                      note: "rzeka → rzece, C./Msc. l.poj., k→c", source: .list),
            Flashcard(pl: "o morzu", ru: "о море", base: "morze", form: "Msc. l.poj.", note: "morze → morzu, Msc. l.poj.", source: .manual),
            Flashcard(pl: "poszłam", ru: "(я) пошла", base: "pójść", form: "cz. przeszły, 1 os. l.poj., ż.", note: "pójść → poszłam", source: .photo),
            Flashcard(pl: "książce", ru: "книге (дат./предл. п.)", base: "książka", form: "C./Msc. l.poj.", alternation: "k→c",
                      note: "książka → książce, k→c", source: .list),
            Flashcard(pl: "mieszkaniu", ru: "квартире (предл. п.)", base: "mieszkanie", form: "Msc. l.poj.", note: "mieszkanie → mieszkaniu", source: .manual),
        ]
        cards[1].box = 3
        cards[1].due = now.addingTimeInterval(3 * 86_400)
        cards[4].box = 5
        cards[4].due = now.addingTimeInterval(12 * 86_400)
        return cards
    }

    static func sampleMistakes() -> [Mistake] {
        [
            Mistake(cardId: "demo-1", check: AnswerChecker.check(given: "rzeka", expected: "rzece")),
            Mistake(cardId: "demo-2", check: AnswerChecker.check(given: "ksiazce", expected: "książce")),
            Mistake(cardId: "demo-3", check: AnswerChecker.check(given: "poszlam", expected: "poszłam")),
        ]
    }

    @MainActor
    static func sampleReview() -> DraftReviewModel {
        let entries = [
            ParsedEntry(pl: "rzece"),
            ParsedEntry(pl: "poszłam", base: "iść"),
            ParsedEntry(pl: "ksiazce"),
            ParsedEntry(pl: "kot", ru: "кот"),
        ]
        var drafts = entries.map { CardDraft(entry: $0, source: .photo) }
        drafts.append(CardDraft(entry: ParsedEntry(pl: "zw[?]lnienie"), source: .photo, lowConfidence: true))
        return DraftReviewModel(drafts: drafts, duplicates: 1, source: .photo, photos: [], wantBase: true)
    }

    @MainActor
    static func sampleStudy() -> StudyModel {
        let card = sampleCards(now: Date())[0]
        let study = StudyModel(cards: [card])
        study.answer = "rzeka"
        _ = study.submit()
        return study
    }
}

/// The root for the screens that cannot be reached through the menu at launch.
struct DemoRoot: View {
    let screen: String
    @Environment(AppModel.self) private var app
    @State private var review = DemoMode.sampleReview()
    @State private var study = DemoMode.sampleStudy()

    var body: some View {
        switch screen {
        case "review":
            NavigationStack {
                DraftReviewView(model: review) { _ in }
            }
        case "study":
            StudyView(model: study)
        case "add":
            AddWordsView()
        case "reader", "panel":
            // The real path: "Сгенерировать" with the fake Claude, then the app opens the reader.
            RootView()
                .task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    app.reading.generate()
                }
        default:
            RootView()
        }
    }
}

/// Answers like Claude would, from fixtures: enough to click through every screen offline.
struct DemoTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(nanoseconds: 400_000_000)
        let url = request.url ?? AIConfiguration.defaultBaseURL
        if request.httpMethod == "GET" {
            return (Data(#"{"id":"claude-sonnet-5-5","type":"model"}"#.utf8), Self.ok(url))
        }
        let body = request.httpBody.flatMap(JSONValue.decode)
        let prompt = body?["messages"]?.arrayValue?.first?["content"]?.arrayValue?.last?["text"]?.stringValue ?? ""
        let reply = try JSONValue.object([
            "type": "message",
            "role": "assistant",
            "model": "claude-sonnet-5-5",
            "content": [["type": "text", "text": .string(Self.answer(to: prompt))]],
            "stop_reason": "end_turn",
        ]).encoded()
        return (reply, Self.ok(url))
    }

    private static func ok(_ url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["content-type": "application/json"])!
    }

    private static func answer(to prompt: String) -> String {
        if prompt.contains("Przetłumacz na rosyjski") {
            return translation(for: quoted(after: "polskie słowo lub frazę: „", in: prompt))
        }
        if prompt.contains("Rosyjskojęzyczna uczennica") {
            return enrich(prompt)
        }
        if prompt.contains("Na zdjęciu") {
            return #"{"items":[{"pl":"rzece","ru":"","base":"","confidence":"high"},{"pl":"ksiazce","ru":"","base":"","confidence":"high"}]}"#
        }
        let text = DemoMode.sampleText
        let generated: JSONValue = [
            "title": .string(text.title),
            "paragraphs": .array(text.paragraphs.map { .string($0) }),
            "keyWords": .array(text.keyWords.map { ["form": .string($0.form), "base": .string($0.base), "ru": .string($0.ru)] }),
            "usedMyWords": ["rzece"],
        ]
        return String(decoding: (try? generated.encoded()) ?? Data(), as: UTF8.self)
    }

    private static func translation(for selection: String) -> String {
        let known: [String: String] = [
            "lekarza": #"{"ru":"врача (род. п.)","base":"lekarz","pos":"существительное","form":"D. l.poj.","alternation":"","note":"","sentence_ru":"На прошлой неделе мне пришлось пойти к врачу, потому что несколько дней болело горло."}"#,
            "rzece": #"{"ru":"реке (предл. п.)","base":"rzeka","pos":"существительное","form":"Msc. l.poj.","alternation":"k→c","note":"","sentence_ru":"Вечером я ещё гуляла у реки… у реки было тихо и спокойно."}"#,
        ]
        return known[selection.lowercased()]
            ?? #"{"ru":"перевод (демо)","base":"","pos":"","form":"","alternation":"","note":"Демо-режим: настоящий перевод придёт от Claude.","sentence_ru":"Перевод предложения (демо)."}"#
    }

    private static func enrich(_ prompt: String) -> String {
        let fixtures: [String: String] = [
            "rzece": #"{"ru":"реке (дат./предл. п.)","base":"rzeka","baseCheck":"","form":"C./Msc. l.poj.","alternation":"k→c","note":"rzeka → rzece, C./Msc. l.poj., k→c","fix":"","isPolish":true}"#,
            "poszłam": #"{"ru":"(я) пошла","base":"pójść","baseCheck":"poszłam — прошедшее время от pójść (сов. вид); iść — несовершенный вид.","form":"cz. przeszły, 1 os. l.poj., ż.","alternation":"","note":"pójść → poszłam, cz. przeszły","fix":"","isPolish":true}"#,
            "ksiazce": #"{"ru":"книге (дат./предл. п.)","base":"książka","baseCheck":"","form":"C./Msc. l.poj.","alternation":"k→c","note":"książka → książce, k→c","fix":"książce","isPolish":true}"#,
            "kot": #"{"ru":"кот","base":"kot","baseCheck":"","form":"M. l.poj.","alternation":"","note":"rodzaj męski","fix":"","isPolish":true}"#,
            "lekarz": #"{"ru":"врач","base":"lekarz","baseCheck":"","form":"M. l.poj.","alternation":"","note":"rodzaj męski","fix":"","isPolish":true}"#,
            "rzeka": #"{"ru":"река","base":"rzeka","baseCheck":"","form":"M. l.poj.","alternation":"","note":"rodzaj żeński","fix":"","isPolish":true}"#,
        ]
        let fallback = #"{"ru":"","base":"","baseCheck":"","form":"","alternation":"","note":"","fix":"","isPolish":true}"#
        // Positions look like "1. rzece" or "2. poszłam [iść]".
        let items = prompt.split(separator: "\n").compactMap { line -> String? in
            guard let dot = line.firstIndex(of: "."), Int(line[..<dot]) != nil else { return nil }
            let rest = line[line.index(after: dot)...]
            let form = (rest.split(separator: "[").first.map(String.init) ?? "").trimmingCharacters(in: .whitespaces)
            return fixtures[form] ?? fallback
        }
        return "{\"items\":[" + items.joined(separator: ",") + "]}"
    }

    private static func quoted(after marker: String, in text: String) -> String {
        guard let start = text.range(of: marker) else { return "" }
        let rest = text[start.upperBound...]
        return String(rest.prefix { $0 != "”" })
    }
}
#endif
