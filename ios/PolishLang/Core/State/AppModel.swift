import Foundation
import Observation

/// Owns the stores and services of the app; created once in `PolishLangApp`.
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable {
        case reading, cards, writing, settings
    }

    var tab: Tab = .reading

    let settings: AppSettings
    let ai: AIService
    let cards: CardStore
    let mistakes: MistakeStore
    let readings: ReadingStore
    let photos: PhotoStore
    let toasts: ToastCenter
    let reading: ReadingSession

    init(directory: URL = AppDirectories.data, secrets: SecretStore, defaults: UserDefaults = .standard) {
        let settings = AppSettings(defaults: defaults)
        let ai = AIService(settings: settings, secrets: secrets)
        let cards = CardStore(file: JSONFileStore(url: directory.appendingPathComponent("cards.json")))
        let mistakes = MistakeStore(file: JSONFileStore(url: directory.appendingPathComponent("mistakes.json")))
        let readings = ReadingStore(file: JSONFileStore(url: directory.appendingPathComponent("texts.json")))
        self.settings = settings
        self.ai = ai
        self.cards = cards
        self.mistakes = mistakes
        self.readings = readings
        self.photos = PhotoStore(directory: directory.appendingPathComponent("photos", isDirectory: true))
        self.toasts = ToastCenter()
        self.reading = ReadingSession(ai: ai, cards: cards, mistakes: mistakes, readings: readings, settings: settings)
    }

    /// Deletes cards together with their mistakes and photos nobody refers to any more.
    func deleteCards(ids: Set<String>) {
        let photoIDs = Set(cards.cards.filter { ids.contains($0.id) }.compactMap(\.photoId))
        cards.delete(ids: ids)
        mistakes.removeAll(forCards: ids)
        let stillUsed = Set(cards.cards.compactMap(\.photoId))
        for photoID in photoIDs.subtracting(stillUsed) {
            photos.delete(photoID)
        }
    }
}
