import Foundation

/// Reading level. The profile is pasted into the prompt as is: it is what makes the levels differ (TZ 2, section 3).
enum CEFRLevel: String, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2"

    static let `default`: CEFRLevel = .b1

    var id: String { rawValue }

    var wordRange: ClosedRange<Int> {
        switch self {
        case .a1: return 60...90
        case .a2: return 90...130
        case .b1: return 130...180
        case .b2: return 180...250
        }
    }

    var easier: CEFRLevel? {
        guard let index = CEFRLevel.allCases.firstIndex(of: self), index > 0 else { return nil }
        return CEFRLevel.allCases[index - 1]
    }

    var harder: CEFRLevel? {
        guard let index = CEFRLevel.allCases.firstIndex(of: self), index + 1 < CEFRLevel.allCases.count else { return nil }
        return CEFRLevel.allCases[index + 1]
    }

    static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool {
        let all = CEFRLevel.allCases
        return all.firstIndex(of: lhs)! < all.firstIndex(of: rhs)!
    }

    /// Level profile in Polish for the generation prompt.
    var profile: String {
        let range = "\(wordRange.lowerBound)–\(wordRange.upperBound) słów"
        switch self {
        case .a1:
            return """
            - Długość: \(range).
            - Zdania: proste, 4–8 słów.
            - Czasy: tylko czas teraźniejszy; czas przyszły z „będę” + bezokolicznik tylko jako gotowa fraza.
            - Przypadki: mianownik, biernik i miejscownik w częstych konstrukcjach (w domu, mam kota).
            - Słownictwo: 1000 najczęstszych słów, codzienne i konkretne.
            - Nie używaj: czasu przeszłego, zdań podrzędnych, imiesłowów.
            """
        case .a2:
            return """
            - Długość: \(range).
            - Zdania: do 12 słów, zdania współrzędnie złożone (i, ale, więc, bo).
            - Czasy: teraźniejszy, przeszły i przyszły; podstawowe pary aspektowe.
            - Przypadki: mianownik, biernik i miejscownik, a także dopełniacz (nie ma, dużo czegoś) i narzędnik (z kimś, jestem nauczycielką).
            - Słownictwo: codzienne oraz częste czasowniki ruchu, miasto, praca.
            - Nie używaj: imiesłowów, trybu przypuszczającego, strony biernej.
            """
        case .b1:
            return """
            - Długość: \(range).
            - Zdania: złożone podrzędnie (który, że, żeby, ponieważ, kiedy, jeśli).
            - Czasy: wszystkie czasy, świadome przeciwstawienie aspektów, tryb przypuszczający (gdybym, chciałabym).
            - Przypadki: wszystkie przypadki, liczebniki z przypadkami.
            - Słownictwo: tematyczne (nauka, praca, zdrowie), wyrażanie opinii.
            - Konstrukcje: wyrażanie opinii (moim zdaniem, wydaje mi się), spójniki (jednak, dlatego).
            - Nie używaj: imiesłowów przysłówkowych uprzednich na -wszy, ciężkiego stylu urzędowego.
            """
        case .b2:
            return """
            - Długość: \(range).
            - Zdania: długie, z kilkoma zdaniami podrzędnymi i wtrąceniami.
            - Czasy: wszystkie, także strona bierna (jest/został zrobiony) i formy bezosobowe na -no/-to (zrobiono).
            - Przypadki: wszystkie, także trudniejszy rząd (zależeć od, dziękować za).
            - Słownictwo: abstrakcyjne, publicystyczne, idiomy, synonimy.
            - Konstrukcje: imiesłowy (-ący, -ny/-ty; rzadziej -ąc, -wszy), spójniki natomiast, w związku z tym, mimo że.
            """
        }
    }
}

enum TextKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case story, dialogue, email, opinion, announcement

    static let `default`: TextKind = .story

    var id: String { rawValue }

    /// Name of the text type in the prompt.
    var promptName: String {
        switch self {
        case .story: return "opowiadanie"
        case .dialogue: return "dialog"
        case .email: return "e-mail"
        case .opinion: return "artykuł z opinią"
        case .announcement: return "ogłoszenie"
        }
    }

    var title: String {
        switch self {
        case .story: return "Рассказ"
        case .dialogue: return "Диалог"
        case .email: return "E-mail / письмо"
        case .opinion: return "Статья с мнением"
        case .announcement: return "Объявление"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TextKind(rawValue: raw) ?? .story
    }
}

struct KeyWord: Codable, Hashable, Sendable {
    /// Exactly as in the text.
    var form: String
    var base: String
    /// Translation of this form.
    var ru: String
}

/// A generated text kept in the reading history (TZ 2, section 6).
struct ReadingText: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var created: Date
    var topic: String
    var level: CEFRLevel
    var kind: TextKind
    var title: String
    var paragraphs: [String]
    var keyWords: [KeyWord]
    var wordCount: Int
    /// Forms of the learner's own words as they appear in the text.
    var usedMyWords: [String]

    init(
        id: String = UUID().uuidString,
        created: Date = Date(),
        topic: String,
        level: CEFRLevel,
        kind: TextKind,
        title: String,
        paragraphs: [String],
        keyWords: [KeyWord],
        usedMyWords: [String] = []
    ) {
        self.id = id
        self.created = created
        self.topic = topic
        self.level = level
        self.kind = kind
        self.title = title
        self.paragraphs = paragraphs
        self.keyWords = keyWords
        self.wordCount = paragraphs.reduce(0) { $0 + PolishText.wordCount($1) }
        self.usedMyWords = usedMyWords
    }

    /// Reading time at about 100 words per minute.
    var readingMinutes: Int {
        max(1, Int((Double(wordCount) / 100).rounded(.up)))
    }

    private enum CodingKeys: String, CodingKey {
        case id, created, topic, level, kind, title, paragraphs, keyWords, wordCount, usedMyWords
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        topic = try c.decodeIfPresent(String.self, forKey: .topic) ?? ""
        level = (try? c.decodeIfPresent(CEFRLevel.self, forKey: .level)) ?? .default
        kind = try c.decodeIfPresent(TextKind.self, forKey: .kind) ?? .default
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        paragraphs = try c.decodeIfPresent([String].self, forKey: .paragraphs) ?? []
        keyWords = try c.decodeIfPresent([KeyWord].self, forKey: .keyWords) ?? []
        wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount)
            ?? paragraphs.reduce(0) { $0 + PolishText.wordCount($1) }
        usedMyWords = try c.decodeIfPresent([String].self, forKey: .usedMyWords) ?? []
    }
}

enum ReadingTopics {
    /// Quick topic chips (TZ 2, section 2).
    static let quick: [String] = [
        "praca", "mieszkanie", "zdrowie", "zakupy", "urząd", "podróże",
        "rodzina", "czas wolny", "edukacja", "środowisko", "technologia", "miasto",
    ]
}
