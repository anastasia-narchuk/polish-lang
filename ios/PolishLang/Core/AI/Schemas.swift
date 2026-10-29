import Foundation

/// JSON schemas for structured outputs. Every object lists all of its properties as required
/// and forbids extra ones, as the API demands.
enum Schemas {
    static let enrich = object([
        "items": array(of: object([
            "ru": string, "base": string, "baseCheck": string, "form": string,
            "alternation": string, "note": string, "fix": string, "isPolish": ["type": "boolean"],
        ])),
    ])

    static let photo = object([
        "items": array(of: object([
            "pl": string, "ru": string, "base": string,
            "confidence": ["type": "string", "enum": ["high", "low"]],
        ])),
    ])

    static let generatedText = object([
        "title": string,
        "paragraphs": array(of: string),
        "keyWords": array(of: object(["form": string, "base": string, "ru": string])),
        "usedMyWords": array(of: string),
    ])

    static let translation = object([
        "ru": string, "base": string, "pos": string, "form": string,
        "alternation": string, "note": string, "sentence_ru": string,
    ])

    private static let string: JSONValue = ["type": "string"]

    private static func array(of items: JSONValue) -> JSONValue {
        ["type": "array", "items": items]
    }

    private static func object(_ properties: [String: JSONValue]) -> JSONValue {
        [
            "type": "object",
            "properties": .object(properties),
            "required": .array(properties.keys.sorted().map { .string($0) }),
            "additionalProperties": false,
        ]
    }
}
