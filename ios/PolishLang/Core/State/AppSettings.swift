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
        static let model = "ai.model"
        static let baseURL = "ai.baseURL"
        static let refusalFallback = "ai.refusalFallback"
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

    var model: String {
        didSet { defaults.set(model, forKey: Key.model) }
    }

    var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Key.baseURL) }
    }

    var refusalFallback: Bool {
        didSet { defaults.set(refusalFallback, forKey: Key.refusalFallback) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        readingLevel = defaults.string(forKey: Key.readingLevel).flatMap(CEFRLevel.init(rawValue:)) ?? .default
        autosaveTexts = defaults.object(forKey: Key.autosaveTexts) as? Bool ?? true
        wantBaseForms = defaults.object(forKey: Key.wantBaseForms) as? Bool ?? true
        photoMode = defaults.string(forKey: Key.photoMode).flatMap(PhotoMode.init(rawValue:)) ?? .highlighted
        model = defaults.string(forKey: Key.model) ?? AIConfiguration.defaultModel
        baseURLString = defaults.string(forKey: Key.baseURL) ?? AIConfiguration.defaultBaseURL.absoluteString
        refusalFallback = defaults.object(forKey: Key.refusalFallback) as? Bool ?? true
    }

    func resetConnection() {
        model = AIConfiguration.defaultModel
        baseURLString = AIConfiguration.defaultBaseURL.absoluteString
        refusalFallback = true
    }
}
