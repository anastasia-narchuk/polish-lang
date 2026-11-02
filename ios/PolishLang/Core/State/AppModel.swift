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
    let writingTexts: WritingStore
    let textErrors: TextErrorStore
    let writing: WritingSession

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
        let photos = PhotoStore(directory: directory.appendingPathComponent("photos", isDirectory: true))
        let toasts = ToastCenter()
        let writingTexts = WritingStore(file: JSONFileStore(url: directory.appendingPathComponent("writing.json")))
        let textErrors = TextErrorStore(file: JSONFileStore(url: directory.appendingPathComponent("text-errors.json")))
        self.photos = photos
        self.toasts = toasts
        self.reading = ReadingSession(ai: ai, cards: cards, mistakes: mistakes, readings: readings, settings: settings)
        self.writingTexts = writingTexts
        self.textErrors = textErrors
        self.writing = WritingSession(
            ai: ai, cards: cards, mistakes: mistakes, store: writingTexts, errors: textErrors,
            drafts: WritingDraftStore(file: JSONFileStore(url: directory.appendingPathComponent("writing-draft.json"))),
            photos: photos, settings: settings, toasts: toasts
        )
    }

    /// Deletes a checked text and its photos.
    func deleteWritingText(id: String) {
        if let photoID = writingTexts.text(id: id)?.photoId { photos.delete(photoID) }
        writingTexts.delete(id: id)
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
