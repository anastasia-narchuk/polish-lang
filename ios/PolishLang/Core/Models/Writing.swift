import Foundation

/// Level of the state exam the writing module prepares for (TZ 3, section 2).
enum ExamLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case b1 = "B1", b2 = "B2"

    var id: String { rawValue }

    /// Pass mark of the writing module, in percent.
    var threshold: Int {
        self == .b1 ? 50 : 60
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ExamLevel(rawValue: raw) ?? .b1
    }
}

/// The writing steps of the ladder ported to iOS (HANDOFF, decision 18). "Słowo" is the card review.
enum WritingStep: String, Codable, CaseIterable, Identifiable, Sendable {
    case akapit, egzamin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .akapit: return "Akapit"
        case .egzamin: return "Egzamin"
        }
    }

    var summary: String {
        switch self {
        case .akapit: return "Абзац 50–80 слов с пятью словами из карточек и связками"
        case .egzamin: return "Задание экзамена: короткая или длинная форма, лучше от руки"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WritingStep(rawValue: raw) ?? .akapit
    }
}

/// How a task was started.
enum WritingMode: String, Codable, Sendable {
    /// "Сегодня" on the Akapit step.
    case akapit
    /// An exam task in training: "Сегодня" on the Egzamin step or "Тренировка формы".
    case exam
    /// "Свой текст": a task from a sample test.
    case own

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WritingMode(rawValue: raw) ?? .own
    }
}

enum TaskLength: String, Codable, CaseIterable, Sendable {
    case short, long

    var title: String {
        self == .short ? "короткая форма" : "длинная форма"
    }
}

/// Forms of the exam texts (TZ 3, 4.1).
enum WritingForm: String, Codable, CaseIterable, Identifiable, Sendable {
    case email, privateLetter, formalLetter, announcement, invitation, wishes, complaint, opinion, story

    var id: String { rawValue }

    /// Name in the prompt.
    var promptName: String {
        switch self {
        case .email: return "e-mail"
        case .privateLetter: return "list prywatny"
        case .formalLetter: return "list formalny"
        case .announcement: return "ogłoszenie"
        case .invitation: return "zaproszenie"
        case .wishes: return "życzenia"
        case .complaint: return "reklamacja"
        case .opinion: return "opinia / rozprawka"
        case .story: return "opowiadanie"
        }
    }

    /// Chip title (the Polish name: it is what the exam calls it).
    var title: String {
        switch self {
        case .email: return "e-mail"
        case .privateLetter: return "list prywatny"
        case .formalLetter: return "list formalny"
        case .announcement: return "ogłoszenie"
        case .invitation: return "zaproszenie"
        case .wishes: return "życzenia"
        case .complaint: return "reklamacja"
        case .opinion: return "opinia / rozprawka"
        case .story: return "opowiadanie"
        }
    }

    var length: TaskLength {
        switch self {
        case .email, .announcement, .invitation, .wishes: return .short
        case .privateLetter, .formalLetter, .complaint, .opinion, .story: return .long
        }
    }

    /// Letters need opening and closing formulas (a line of the self-check list).
    var isLetter: Bool {
        switch self {
        case .email, .privateLetter, .formalLetter, .complaint, .invitation: return true
        case .announcement, .wishes, .opinion, .story: return false
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WritingForm(rawValue: raw) ?? .email
    }
}

/// A part of the plan with Polish sentence starters (TZ 3, 4.3).
struct PlanPart: Codable, Hashable, Sendable {
    var ru: String
    var phrases: [String]
}

/// A content idea: the Russian thought is shown first, the Polish collocation on a tap.
struct WritingIdea: Codable, Hashable, Sendable {
    var ru: String
    var pl: String
}

/// A writing task (TZ 3, 7.1).
struct WritingTask: Codable, Hashable, Sendable {
    /// Name of the form as the model wrote it ("e-mail do koleżanki").
    var form: String
    /// "formalny" or "nieformalny".
    var register: String
    var polecenie: String
    var punkty: [String]
    /// Target number of words.
    var words: Int
    /// Short Russian translation of the task.
    var ru: String
    var plan: [PlanPart]
    var connectors: [String]
    var ideas: [WritingIdea]
    /// Words that must be used (Akapit: five words from the cards).
    var must: [String] = []
    /// Connectors that must be used (Akapit: two from the list).
    var mustConnectors: [String] = []
    var level: ExamLevel = .b1
    var kind: WritingForm?
    var length: TaskLength?
    var topic: String = ""

    var isFormal: Bool {
        register.lowercased().hasPrefix("formal")
    }

    private enum CodingKeys: String, CodingKey {
        case form, register, polecenie, punkty, words, ru, plan, connectors, ideas, must, mustConnectors, level, kind, length, topic
    }

    init(
        form: String, register: String, polecenie: String, punkty: [String], words: Int, ru: String,
        plan: [PlanPart], connectors: [String], ideas: [WritingIdea], must: [String] = [], mustConnectors: [String] = [],
        level: ExamLevel = .b1, kind: WritingForm? = nil, length: TaskLength? = nil, topic: String = ""
    ) {
        self.form = form
        self.register = register
        self.polecenie = polecenie
        self.punkty = punkty
        self.words = words
        self.ru = ru
        self.plan = plan
        self.connectors = connectors
        self.ideas = ideas
        self.must = must
        self.mustConnectors = mustConnectors
        self.level = level
        self.kind = kind
        self.length = length
        self.topic = topic
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        form = try c.decodeIfPresent(String.self, forKey: .form) ?? ""
        register = try c.decodeIfPresent(String.self, forKey: .register) ?? ""
        polecenie = try c.decodeIfPresent(String.self, forKey: .polecenie) ?? ""
        punkty = try c.decodeIfPresent([String].self, forKey: .punkty) ?? []
        words = try c.decodeIfPresent(Int.self, forKey: .words) ?? 0
        ru = try c.decodeIfPresent(String.self, forKey: .ru) ?? ""
        plan = try c.decodeIfPresent([PlanPart].self, forKey: .plan) ?? []
        connectors = try c.decodeIfPresent([String].self, forKey: .connectors) ?? []
        ideas = try c.decodeIfPresent([WritingIdea].self, forKey: .ideas) ?? []
        must = try c.decodeIfPresent([String].self, forKey: .must) ?? []
        mustConnectors = try c.decodeIfPresent([String].self, forKey: .mustConnectors) ?? []
        level = try c.decodeIfPresent(ExamLevel.self, forKey: .level) ?? .b1
        kind = try? c.decodeIfPresent(WritingForm.self, forKey: .kind)
        length = try? c.decodeIfPresent(TaskLength.self, forKey: .length)
        topic = try c.decodeIfPresent(String.self, forKey: .topic) ?? ""
    }
}

// MARK: - The check (TZ 3, 7.4)

struct TextError: Codable, Hashable, Sendable {
    /// Exactly as in the learner's text, the shortest piece with the mistake.
    var fragment: String
    var correction: String
    /// ortografia, gramatyka, leksyka, składnia, interpunkcja.
    var type: String
    var ruleRu: String
}

enum PointStatus: String, Codable, Sendable {
    case yes = "tak", partly = "częściowo", no = "nie"

    var mark: String {
        switch self {
        case .yes: return "✓"
        case .partly: return "≈"
        case .no: return "✗"
        }
    }

    init(model value: String) {
        let lowered = value.trimmed.lowercased()
        if lowered.hasPrefix("tak") || lowered == "yes" {
            self = .yes
        } else if lowered.hasPrefix("częś") || lowered.hasPrefix("czes") || lowered.hasPrefix("partial") {
            self = .partly
        } else {
            self = .no
        }
    }
}

struct PointCoverage: Codable, Hashable, Sendable {
    var punkt: String
    var status: PointStatus
    var quote: String
}

struct RegisterCheck: Codable, Hashable, Sendable {
    var expected: String
    var detected: String
    var consistent: Bool
    var issuesRu: [String]
}

/// The five criteria, 0–5 each.
struct CriteriaScores: Codable, Hashable, Sendable {
    var zadanie: Int
    var spojnosc: Int
    var gramatyka: Int
    var leksyka: Int
    var ortografia: Int

    subscript(criterion: Criterion) -> Int {
        switch criterion {
        case .zadanie: return zadanie
        case .spojnosc: return spojnosc
        case .gramatyka: return gramatyka
        case .leksyka: return leksyka
        case .ortografia: return ortografia
        }
    }

    var total: Int {
        zadanie + spojnosc + gramatyka + leksyka + ortografia
    }

    /// Our approximation of the official scale: the sum of the criteria out of 25 (TZ 3, 7.4).
    var percent: Int {
        Int((Double(total) / 25 * 100).rounded())
    }
}

/// The criteria of the exam grade, in the order of the feedback screen.
enum Criterion: String, CaseIterable, Identifiable, Sendable {
    case zadanie, spojnosc, gramatyka, leksyka, ortografia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zadanie: return "Выполнение задания"
        case .spojnosc: return "Связность"
        case .gramatyka: return "Грамматика"
        case .leksyka: return "Лексика"
        case .ortografia: return "Орфография и пунктуация"
        }
    }
}

struct Upgrade: Codable, Hashable, Sendable {
    var plain: String
    var better: String
    var ru: String
}

struct NewWord: Codable, Hashable, Sendable {
    /// The form to use in this context.
    var pl: String
    var base: String
    var ru: String
}

struct TextCheck: Codable, Hashable, Sendable {
    var errors: [TextError]
    var points: [PointCoverage]
    var register: RegisterCheck
    var scores: CriteriaScores
    var correctedText: String
    var upgrade: [Upgrade]
    var newWords: [NewWord]
    var used: [String]
    var summaryRu: String
}

/// What the learner looked at in the support panel.
struct SupportStats: Codable, Hashable, Sendable {
    /// The panel was opened although the step keeps it hidden: the text is marked "с опорой".
    var opened = false
    var ideasRevealed = 0
    var ideasTotal = 0
}

/// The manual self-check list before sending (TZ 3, 4.2). It never blocks the check.
struct WritingChecklist: Codable, Hashable, Sendable {
    var points = false
    var length = false
    var register = false
    var formulas = false
    var ogonki = false
}

/// A checked text in "Мои тексты" (TZ 3, section 10).
struct WritingText: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var created: Date
    var mode: WritingMode
    var step: WritingStep?
    var examLevel: ExamLevel
    var task: WritingTask
    var ideasDraft: String
    var text: String
    var hand: Bool
    /// Batch id in the photo store.
    var photoId: String?
    var seconds: Int
    var support: SupportStats
    var checklist: WritingChecklist
    var result: TextCheck
    /// Percent by our scale.
    var score: Int
    /// Points of the exam task (e.g. 14 of 20), for exam tasks only.
    var taskPoints: Int?
    var taskWeight: Int?

    var wordCount: Int {
        PolishText.wordCount(text)
    }

    var passed: Bool {
        score >= examLevel.threshold
    }
}
