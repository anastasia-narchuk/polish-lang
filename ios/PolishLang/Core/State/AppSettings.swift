import Foundation
import Observation

/// User preferences kept in UserDefaults. The API key lives in the Keychain, see `AIService`.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let readingLevel = "reading.level"
        static let autosaveTexts = "reading.autosave"
        static let wantBaseForms = "cards.wantBaseForms"
        static let photoMode = "cards.photoMode"
        static let provider = "ai.provider"
        static let model = "ai.model"
        static let geminiModel = "ai.geminiModel"
        static let geminiFallback = "ai.geminiFallback"
        static let baseURL = "ai.baseURL"
        static let refusalFallback = "ai.refusalFallback"
        static let writing = "writing.settings"
        static let writingStep = "writing.step"
        static let egzaminUnlocked = "writing.egzaminUnlocked"
        static let nextExamLength = "writing.nextExamLength"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Last chosen level, B1 by default (TZ 2, section 2).
    var readingLevel: CEFRLevel {
        didSet { defaults.set(readingLevel.rawValue, forKey: Key.readingLevel) }
    }

    /// Every generated text goes to the history.
    var autosaveTexts: Bool {
        didSet { defaults.set(autosaveTexts, forKey: Key.autosaveTexts) }
    }

    /// Ask AI for the base form and a note even when the learner typed a translation herself.
    var wantBaseForms: Bool {
        didSet { defaults.set(wantBaseForms, forKey: Key.wantBaseForms) }
    }

    var photoMode: PhotoMode {
        didSet { defaults.set(photoMode.rawValue, forKey: Key.photoMode) }
    }

    /// Who answers: Claude or Gemini. Each has its own key in the Keychain.
    var provider: AIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Key.provider) }
    }

    /// Claude model.
    var model: String {
        didSet { defaults.set(model, forKey: Key.model) }
    }

    var geminiModel: String {
        didSet { defaults.set(geminiModel, forKey: Key.geminiModel) }
    }

    /// When the Gemini model is overloaded, ask the lighter one once.
    var geminiFallback: Bool {
        didSet { defaults.set(geminiFallback, forKey: Key.geminiFallback) }
    }

    var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Key.baseURL) }
    }

    var refusalFallback: Bool {
        didSet { defaults.set(refusalFallback, forKey: Key.refusalFallback) }
    }

    /// Exam level, word limits, task weights and time of the writing module (TZ 3, section 10).
    var writing: WritingSettings {
        didSet {
            if let data = try? JSONEncoder().encode(writing) { defaults.set(data, forKey: Key.writing) }
        }
    }

    /// The current step of the writing ladder.
    var writingStep: WritingStep {
        didSet { defaults.set(writingStep.rawValue, forKey: Key.writingStep) }
    }

    /// Egzamin was opened early or by progress.
    var egzaminUnlocked: Bool {
        didSet { defaults.set(egzaminUnlocked, forKey: Key.egzaminUnlocked) }
    }

    /// The Egzamin step alternates the short and the long form.
    var nextExamLength: TaskLength {
        didSet { defaults.set(nextExamLength.rawValue, forKey: Key.nextExamLength) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        readingLevel = defaults.string(forKey: Key.readingLevel).flatMap(CEFRLevel.init(rawValue:)) ?? .default
        autosaveTexts = defaults.object(forKey: Key.autosaveTexts) as? Bool ?? true
        wantBaseForms = defaults.object(forKey: Key.wantBaseForms) as? Bool ?? true
        photoMode = defaults.string(forKey: Key.photoMode).flatMap(PhotoMode.init(rawValue:)) ?? .highlighted
        provider = defaults.string(forKey: Key.provider).flatMap(AIProvider.init(rawValue:)) ?? .claude
        model = defaults.string(forKey: Key.model) ?? AIConfiguration.defaultModel
        geminiModel = defaults.string(forKey: Key.geminiModel) ?? GeminiClient.defaultModel
        geminiFallback = defaults.object(forKey: Key.geminiFallback) as? Bool ?? true
        baseURLString = defaults.string(forKey: Key.baseURL) ?? AIConfiguration.defaultBaseURL.absoluteString
        refusalFallback = defaults.object(forKey: Key.refusalFallback) as? Bool ?? true
        writing = defaults.data(forKey: Key.writing).flatMap { try? JSONDecoder().decode(WritingSettings.self, from: $0) } ?? WritingSettings()
        writingStep = defaults.string(forKey: Key.writingStep).flatMap(WritingStep.init(rawValue:)) ?? .akapit
        egzaminUnlocked = defaults.object(forKey: Key.egzaminUnlocked) as? Bool ?? false
        nextExamLength = defaults.string(forKey: Key.nextExamLength).flatMap(TaskLength.init(rawValue:)) ?? .short
    }

    func resetConnection() {
        model = AIConfiguration.defaultModel
        geminiModel = GeminiClient.defaultModel
        geminiFallback = true
        baseURLString = AIConfiguration.defaultBaseURL.absoluteString
        refusalFallback = true
    }
}
