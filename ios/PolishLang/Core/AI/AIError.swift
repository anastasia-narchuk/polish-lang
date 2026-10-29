import Foundation

enum AIError: Error, Equatable, Sendable {
    /// No API key in the settings.
    case notConfigured
    case offline
    case timeout
    case cancelled
    case unauthorized
    case forbidden(String)
    case billing
    case modelNotFound(String)
    case rateLimited(retryAfter: TimeInterval?)
    case overloaded
    case server(Int)
    case badRequest(String)
    /// `stop_reason: "refusal"` or a reply with nothing usable in it.
    case refusal
    /// `stop_reason: "max_tokens"`.
    case truncated
    case invalidResponse
    case network(String)

    var userMessage: String {
        switch self {
        case .notConfigured: return "AI не подключён: добавь API-ключ Claude в настройках."
        case .offline: return "Нет подключения к интернету."
        case .timeout: return "AI слишком долго отвечал. Попробуй ещё раз."
        case .cancelled: return "Остановлено."
        case .unauthorized: return "API-ключ не подошёл. Проверь его в настройках."
        case .forbidden(let message): return "Доступ запрещён: \(message)"
        case .billing: return "Проблема с оплатой в аккаунте Anthropic."
        case .modelNotFound(let model): return "Модель \(model) недоступна для этого ключа. Проверь название модели в настройках."
        case .rateLimited: return "Подожди минуту: слишком частые запросы."
        case .overloaded: return "AI сейчас перегружен. Попробуй через минуту."
        case .server(let status): return "Ошибка на стороне AI (\(status)). Попробуй ещё раз."
        case .badRequest(let message): return "Запрос не принят: \(message)"
        case .refusal: return "AI отказался отвечать на этот запрос."
        case .truncated: return "Ответ AI обрезан. Попробуй ещё раз."
        case .invalidResponse: return "AI вернул ответ в неожиданном формате. Попробуй ещё раз."
        case .network(let message): return "Ошибка сети: \(message)"
        }
    }

    /// AI cannot be reached at all: no key or no network (TZ 2, section 7: "AI недоступен").
    var meansUnavailable: Bool {
        self == .notConfigured || self == .offline
    }
}
