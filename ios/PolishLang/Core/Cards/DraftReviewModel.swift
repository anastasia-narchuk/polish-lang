import Foundation
import Observation

/// The check screen before saving new words (TZ 1, section 3).
@MainActor
@Observable
final class DraftReviewModel: Identifiable, Hashable {
    let id = UUID()
    var drafts: [CardDraft]
    /// Forms skipped because they are already in the cards.
    let duplicates: Int
    let source: CardSource
    /// Photos the words came from, shown next to the list for comparison.
    let photos: [Data]
    let wantBase: Bool
    private(set) var isWorking = false
    private(set) var failure: AIError?

    init(drafts: [CardDraft], duplicates: Int, source: CardSource, photos: [Data] = [], wantBase: Bool) {
        self.drafts = drafts
        self.duplicates = duplicates
        self.source = source
        self.photos = photos
        self.wantBase = wantBase
    }

    var checkedCount: Int {
        drafts.filter(\.include).count
    }

    var pendingCount: Int {
        drafts.filter { !$0.answered && $0.needsAI(wantBase: wantBase) }.count
    }

    /// Sends the rows that still need AI in batches of 40. Already typed text stays as is.
    func enrich(using ai: AIService) async {
        guard !isWorking else { return }
        let indices = drafts.indices.filter { !drafts[$0].answered && drafts[$0].needsAI(wantBase: wantBase) }
        guard !indices.isEmpty else { return }
        guard ai.hasKey else {
            failure = .notConfigured
            return
        }
        isWorking = true
        failure = nil
        let outcome = await ai.enrich(indices.map { drafts[$0].enrichInput })
        for (offset, index) in indices.enumerated() where index < drafts.count && offset < outcome.results.count {
            drafts[index].apply(outcome.results[offset])
        }
        failure = outcome.failure
        isWorking = false
    }

    nonisolated static func == (lhs: DraftReviewModel, rhs: DraftReviewModel) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
