import Foundation

/// Prompts and schemas of the writing module (TZ 3, section 7). Prompts are in Polish,
/// explanations for the learner come back in Russian.
enum WritingPrompts {
    /// Connectors for the Akapit step: two of them must be used (from the "Pisz po polsku" artifact).
    static let connectors = [
        "po pierwsze", "po drugie", "moim zdaniem", "z jednej strony", "z drugiej strony", "poza tym", "dlatego",
        "jednak", "na przykład", "podsumowując", "w związku z tym", "mimo że", "chociaż", "natomiast",
        "przede wszystkim", "wydaje mi się, że", "co więcej", "na koniec",
    ]

    /// Forms of a random exam task by level and length (from `P.exam` of the artifact).
    static func examForms(level: ExamLevel, length: TaskLength) -> String {
        switch (level, length) {
        case (.b1, .short):
            return "krótka forma użytkowa, np. życzenia, pozdrowienia z wakacji, zaproszenie, ogłoszenie, notatka dla współlokatora, krótki e-mail"
        case (.b1, .long):
            return "dłuższa forma, np. list prywatny lub oficjalny, e-mail z reklamacją, opowiadanie o wydarzeniu, opinia na forum"
        case (.b2, .short):
            return "krótsza forma, np. e-mail lub list z prośbą, informacją, reklamacją, ogłoszenie, zaproszenie, notatka służbowa"
        case (.b2, .long):
            return "dłuższa forma argumentacyjna, np. rozprawka, artykuł z opinią, list formalny (do redakcji, do urzędu) z uzasadnieniem stanowiska"
        }
    }

    /// The Akapit step: a short task where the learner's words fit naturally.
    static let akapitForms = "krótka forma: e-mail, wpis na forum, opinia, wiadomość do znajomego albo notatka"

    /// TZ 3, 7.1: one task. `words` is "około 150" or "50–80".
    static func task(level: ExamLevel, form: String, topic: String, words: String, must: [String], mustConnectors: [String]) -> String {
        var lines = [
            "Jesteś autorem zadań Państwowego Egzaminu Certyfikatowego z języka polskiego jako obcego, poziom \(level.rawValue).",
            "Ułóż jedno zadanie z części „Pisanie”.",
            "Forma: \(form). Temat: \(topic.isEmpty ? "z życia codziennego w Polsce" : Prompts.sanitize(topic)). Liczba słów: \(words).",
        ]
        if !topic.isEmpty {
            lines.append("Temat może być podany po rosyjsku — zadanie pisz po polsku.")
        }
        if !must.isEmpty {
            var line = "W zadaniu musi dać się naturalnie użyć słów: \(must.map(Prompts.sanitize).joined(separator: ", "))"
            if !mustConnectors.isEmpty {
                line += ", oraz wyrażeń: \(mustConnectors.joined(separator: ", "))"
            }
            lines.append(line + ".")
        }
        lines += taskFields(words: nil)
        return lines.joined(separator: "\n")
    }

    /// "Свой текст": a task the learner brought from a sample test, turned into the same structure.
    static func ownTask(text: String, level: ExamLevel, words: Int) -> String {
        var lines = [
            "Jesteś nauczycielem języka polskiego jako obcego. Rosyjskojęzyczna uczennica (poziom \(level.rawValue)) ma napisać tekst na około \(words) słów. Oto zadanie, które przyniosła (po polsku albo po rosyjsku):",
            "\"\"\"",
            String(text.trimmed.prefix(2_000)),
            "\"\"\"",
            "Przygotuj je do pracy tak jak zadanie egzaminu. \"polecenie\": treść zadania po polsku; jeśli zadanie jest po polsku, przepisz je bez zmian. \"punkty\": elementy treści, które zadanie każe uwzględnić; jeśli ich nie wymienia, podaj 3 najważniejsze.",
        ]
        lines += taskFields(words: words)
        return lines.joined(separator: "\n")
    }

    private static func taskFields(words: Int?) -> [String] {
        [
            "Dla zadania:",
            #"- "form", "register": "formalny"|"nieformalny", "polecenie" (w stylu egzaminu), "punkty" (3–4 elementy treści do uwzględnienia), "words"\#(words.map { " (\($0))" } ?? ""), "ru" (краткий перевод задания на русский),"#,
            #"- "plan": 3–4 części w kolejności [{"ru": nazwa części po rosyjsku, np. "Вступление", "Просьба", "Прощание", "phrases": 2–3 polskie początki zdań typowe dla tej formy}]. W listach i e-mailach plan zawiera formuły powitania i pożegnania (np. „Szanowni Państwo,”, „Z poważaniem”, „Pozdrawiam serdecznie”),"#,
            #"- "connectors": 4–6 wyrażeń łączących pasujących do formy,"#,
            #"- "ideas": 5–6 [{"ru": myśl po rosyjsku 2–5 słów, "pl": kluczowa polska kolokacja}]."#,
            #"Odpowiedz tylko JSON: {"task":{"form":"","register":"","polecenie":"","punkty":[],"words":0,"ru":"","plan":[{"ru":"","phrases":[]}],"connectors":[],"ideas":[{"ru":"","pl":""}]}}"#,
        ]
    }

    /// TZ 3, 7.2: the handwritten text word for word (from `P.transcribe` of the artifact). Plain text reply.
    static let transcribe = """
    Na zdjęciu (lub zdjęciach) jest odręczny tekst uczennicy po polsku. Kilka zdjęć to kolejne strony jednego tekstu, w tej kolejności. Przepisz go DOKŁADNIE tak, jak jest napisany — ze wszystkimi błędami ortograficznymi i gramatycznymi, brakującymi lub zbędnymi ogonkami, interpunkcją i podziałem na akapity. Niczego nie poprawiaj i nie dopisuj. Słowo, którego nie da się odczytać, zapisz jako [?]. Odpowiedz wyłącznie przepisanym tekstem, bez komentarzy.
    """

    /// TZ 3, 7.4: the full check, with the coverage of the task points and the register.
    static func check(task: WritingTask, text: String) -> String {
        var lines = [
            "Jesteś egzaminatorem Państwowego Egzaminu Certyfikatowego z języka polskiego, poziom \(task.level.rawValue). Oceń tekst rosyjskojęzycznej uczennicy.",
            "ZADANIE: \(task.form.isEmpty ? "" : task.form + ". ")\(task.polecenie)",
        ]
        if !task.punkty.isEmpty {
            lines.append("Punkty: \(task.punkty.joined(separator: "; ")).")
        }
        lines.append("Rejestr: \(task.register.isEmpty ? "odpowiedni do formy" : task.register). Długość: około \(task.words) słów (tekst ma \(PolishText.wordCount(text))).")
        let must = task.must + task.mustConnectors
        if !must.isEmpty {
            lines.append("Obowiązkowe słowa: \(must.joined(separator: ", ")).")
        }
        lines += [
            "TEKST:",
            "\"\"\"",
            text,
            "\"\"\"",
            "Zwróć JSON:",
            #"- "errors": [{"fragment": DOKŁADNY fragment z tekstu uczennicy (taki sam zapis), najkrótszy fragment z błędem, "correction": poprawna forma tego fragmentu, "type": "ortografia"|"gramatyka"|"leksyka"|"składnia"|"interpunkcja", "rule_ru": wyjaśnienie reguły po rosyjsku, max 20 słów}] — każdy błąd osobno; nie oznaczaj poprawnych wariantów stylistycznych,"#,
            #"- "points": [{"punkt": tekst punktu, "status": "tak"|"częściowo"|"nie", "quote": cytat z tekstu, w którym punkt jest zrealizowany, albo ""}] — po jednym na każdy punkt zadania, w tej samej kolejności,"#,
            #"- "register": {"expected": rejestr wymagany przez zadanie, "detected": rejestr tekstu, "consistent": true/false, "issues_ru": ["…"]} — sprawdź, czy forma zwracania się (Pan/Pani/Państwo albo ty) i formuły powitania i pożegnania są jednolite i pasują do zadania; problemy opisz po rosyjsku,"#,
            #"- "scores": {"zadanie","spojnosc","gramatyka","leksyka","ortografia"} każde 0–5 jak na egzaminie: "zadanie" (realizacja polecenia, wszystkie punkty, forma, długość; pominięty punkt — najwyżej 3; tekst dużo dłuższy lub krótszy od wymaganego — obniż ocenę i wyjaśnij w summary_ru), "spojnosc" (spójność, logika, akapity, wyrażenia łączące), "gramatyka" (poprawność gramatyczna), "leksyka" (bogactwo i trafność słownictwa), "ortografia" (ortografia i interpunkcja),"#,
            #"- "corrected_text": cały tekst poprawiony minimalnie, z zachowaniem stylu uczennicy,"#,
            #"- "upgrade": 3 propozycje {"plain": fragment uczennicy, "better": ten sam sens na wyższym poziomie, "ru": po co to, krótko po rosyjsku},"#,
            #"- "new_words": 3–6 słów lub kolokacji przydatnych w tym temacie, których uczennica nie użyła: {"pl": forma, w jakiej należy ich użyć w tym kontekście, "base": forma podstawowa, "ru": tłumaczenie tej formy},"#,
            #"- "used": które obowiązkowe słowa zostały użyte (w dowolnej formie),"#,
            #"- "summary_ru": 2–3 zdania po rosyjsku: co dobrze, co najważniejsze do poprawy."#,
            "Oceniaj uczciwie i surowo, jak na prawdziwym egzaminie, bez zawyżania.",
            #"Odpowiedz tylko JSON: {"errors":[],"points":[],"register":{"expected":"","detected":"","consistent":true,"issues_ru":[]},"scores":{"zadanie":0,"spojnosc":0,"gramatyka":0,"leksyka":0,"ortografia":0},"corrected_text":"","upgrade":[],"new_words":[],"used":[],"summary_ru":""}"#,
        ]
        return lines.joined(separator: "\n")
    }

    // MARK: Schemas

    static let taskSchema = schemaObject([
        "task": schemaObject([
            "form": string,
            "register": ["type": "string", "enum": ["formalny", "nieformalny"]],
            "polecenie": string,
            "punkty": array(of: string),
            "words": ["type": "integer"],
            "ru": string,
            "plan": array(of: schemaObject(["ru": string, "phrases": array(of: string)])),
            "connectors": array(of: string),
            "ideas": array(of: schemaObject(["ru": string, "pl": string])),
        ]),
    ])

    static let checkSchema = schemaObject([
        "errors": array(of: schemaObject([
            "fragment": string, "correction": string,
            "type": ["type": "string", "enum": ["ortografia", "gramatyka", "leksyka", "składnia", "interpunkcja"]],
            "rule_ru": string,
        ])),
        "points": array(of: schemaObject([
            "punkt": string,
            "status": ["type": "string", "enum": ["tak", "częściowo", "nie"]],
            "quote": string,
        ])),
        "register": schemaObject([
            "expected": string, "detected": string, "consistent": ["type": "boolean"], "issues_ru": array(of: string),
        ]),
        "scores": schemaObject([
            "zadanie": integer, "spojnosc": integer, "gramatyka": integer, "leksyka": integer, "ortografia": integer,
        ]),
        "corrected_text": string,
        "upgrade": array(of: schemaObject(["plain": string, "better": string, "ru": string])),
        "new_words": array(of: schemaObject(["pl": string, "base": string, "ru": string])),
        "used": array(of: string),
        "summary_ru": string,
    ])

    private static let string: JSONValue = ["type": "string"]
    private static let integer: JSONValue = ["type": "integer"]

    private static func array(of items: JSONValue) -> JSONValue {
        ["type": "array", "items": items]
    }

    private static func schemaObject(_ properties: [String: JSONValue]) -> JSONValue {
        [
            "type": "object",
            "properties": .object(properties),
            "required": .array(properties.keys.sorted().map { .string($0) }),
            "additionalProperties": false,
        ]
    }
}
