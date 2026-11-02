import Foundation

/// Tolerant reading of the writing replies: snake_case or camelCase keys, numbers as text,
/// scores clamped to 0–5, empty items dropped.
enum WritingParser {
    /// TZ 3, 7.1 reply: {"task": {...}} or the task object itself.
    static func task(from text: String) throws -> WritingTask {
        guard let json = TolerantJSON.parse(text), json.objectValue != nil else { throw AIError.invalidResponse }
        let task = json["task"]?.objectValue != nil ? json["task"]! : (json["tasks"]?.arrayValue?.first ?? json)
        let polecenie = string(task["polecenie"])
        // An empty task is how a polite refusal inside valid JSON looks.
        guard !polecenie.isEmpty else { throw AIError.refusal }
        let plan = (task["plan"]?.arrayValue ?? []).compactMap { part -> PlanPart? in
            let ru = string(part["ru"])
            let phrases = strings(part["phrases"])
            return ru.isEmpty && phrases.isEmpty ? nil : PlanPart(ru: ru, phrases: phrases)
        }
        let ideas = (task["ideas"]?.arrayValue ?? []).compactMap { idea -> WritingIdea? in
            let ru = string(idea["ru"])
            let pl = string(idea["pl"])
            return ru.isEmpty || pl.isEmpty ? nil : WritingIdea(ru: ru, pl: pl)
        }
        return WritingTask(
            form: string(task["form"]),
            register: string(task["register"]),
            polecenie: polecenie,
            punkty: strings(task["punkty"]),
            words: int(task["words"]) ?? 0,
            ru: string(task["ru"]),
            plan: plan,
            connectors: strings(task["connectors"]),
            ideas: ideas
        )
    }

    /// TZ 3, 7.4 reply.
    static func check(from text: String) throws -> TextCheck {
        guard let json = TolerantJSON.parse(text), json.objectValue != nil else { throw AIError.invalidResponse }
        guard let scores = json["scores"], scores.objectValue != nil else { throw AIError.invalidResponse }
        let errors = (json["errors"]?.arrayValue ?? []).compactMap { error -> TextError? in
            let fragment = string(error["fragment"])
            let correction = string(error["correction"])
            guard !fragment.isEmpty, PolishText.dedupKey(fragment) != PolishText.dedupKey(correction) || fragment != correction else { return nil }
            return TextError(fragment: fragment, correction: correction, type: string(error["type"]).lowercased(), ruleRu: string(error["rule_ru"] ?? error["ruleRu"]))
        }
        let points = (json["points"]?.arrayValue ?? []).compactMap { point -> PointCoverage? in
            let punkt = string(point["punkt"])
            guard !punkt.isEmpty else { return nil }
            return PointCoverage(punkt: punkt, status: PointStatus(model: string(point["status"])), quote: string(point["quote"]))
        }
        let register = json["register"]
        let upgrades = (json["upgrade"]?.arrayValue ?? []).compactMap { item -> Upgrade? in
            let better = string(item["better"])
            return better.isEmpty ? nil : Upgrade(plain: string(item["plain"]), better: better, ru: string(item["ru"]))
        }
        let newWords = (json["new_words"]?.arrayValue ?? json["newWords"]?.arrayValue ?? []).compactMap { item -> NewWord? in
            let pl = string(item["pl"])
            return pl.isEmpty ? nil : NewWord(pl: pl, base: string(item["base"]), ru: string(item["ru"]))
        }
        return TextCheck(
            errors: errors,
            points: points,
            register: RegisterCheck(
                expected: string(register?["expected"]),
                detected: string(register?["detected"]),
                consistent: register?["consistent"]?.boolValue ?? true,
                issuesRu: strings(register?["issues_ru"] ?? register?["issuesRu"])
            ),
            scores: CriteriaScores(
                zadanie: score(scores["zadanie"]),
                spojnosc: score(scores["spojnosc"] ?? scores["spójność"]),
                gramatyka: score(scores["gramatyka"]),
                leksyka: score(scores["leksyka"]),
                ortografia: score(scores["ortografia"])
            ),
            correctedText: string(json["corrected_text"] ?? json["correctedText"]),
            upgrade: upgrades,
            newWords: newWords,
            used: strings(json["used"]),
            summaryRu: string(json["summary_ru"] ?? json["summaryRu"])
        )
    }

    private static func string(_ value: JSONValue?) -> String {
        value?.stringValue?.trimmed ?? ""
    }

    private static func strings(_ value: JSONValue?) -> [String] {
        (value?.arrayValue ?? []).map { string($0) }.filter { !$0.isEmpty }
    }

    private static func int(_ value: JSONValue?) -> Int? {
        switch value {
        case .int(let int): return int
        case .double(let double): return Int(double.rounded())
        case .string(let text): return Int(text.trimmed) ?? Double(text.trimmed.replacingOccurrences(of: ",", with: ".")).map { Int($0.rounded()) }
        default: return nil
        }
    }

    private static func score(_ value: JSONValue?) -> Int {
        min(5, max(0, int(value) ?? 0))
    }
}
