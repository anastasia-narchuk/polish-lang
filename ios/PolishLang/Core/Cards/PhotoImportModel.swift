import Foundation
import Observation

/// Words from photos of notes or a textbook page (TZ 1, section 2.3).
@MainActor
@Observable
final class PhotoImportModel {
    /// Prepared JPEGs, at most `PolishAI.maxPhotos`.
    private(set) var photos: [Data] = []
    private(set) var isRecognizing = false
    var isPreparing = false
    var message: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    var canAddMore: Bool {
        photos.count < PolishAI.maxPhotos
    }

    func add(_ jpegs: [Data]) {
        let room = max(0, PolishAI.maxPhotos - photos.count)
        if jpegs.count > room {
            message = "За один раз — до \(PolishAI.maxPhotos) фото. Лишние не добавлены."
        }
        photos += jpegs.prefix(room)
    }

    func remove(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
    }

    func reset() {
        task?.cancel()
        photos = []
        message = nil
        isRecognizing = false
    }

    func stop() {
        task?.cancel()
    }

    /// Recognizes the words; rows without a translation or base form go through the batch
    /// translation on the check screen. Calls `onReady` with that screen's model.
    func recognize(mode: PhotoMode, ai: AIService, existingKeys: Set<String>, onReady: @escaping (DraftReviewModel) -> Void) {
        guard !photos.isEmpty, !isRecognizing else { return }
        message = nil
        isRecognizing = true
        let photos = self.photos
        task = Task {
            defer { self.isRecognizing = false }
            do {
                let images = photos.map { AIImage(mediaType: "image/jpeg", data: $0) }
                let items = try await ai.recognize(images: images, mode: mode)
                guard !items.isEmpty else {
                    self.message = "Не нашла польских слов на фото. Попробуй режим «Все польские слова» или сфотографируй ближе"
                    return
                }
                let drafts = items.map {
                    CardDraft(entry: ParsedEntry(pl: $0.pl, base: $0.base, ru: $0.ru), source: .photo, lowConfidence: $0.lowConfidence)
                }
                let prepared = DraftBuilder.prepare(drafts, existingKeys: existingKeys)
                guard !prepared.drafts.isEmpty else {
                    self.message = "Эти слова уже есть в тетради"
                    return
                }
                onReady(DraftReviewModel(drafts: prepared.drafts, duplicates: prepared.duplicates, source: .photo, photos: photos, wantBase: true))
            } catch let error as AIError {
                if error != .cancelled { self.message = error.userMessage }
            } catch {
                self.message = error.localizedDescription
            }
        }
    }

    /// Waits for the running recognition (used by tests).
    func waitForRecognition() async {
        await task?.value
    }
}
