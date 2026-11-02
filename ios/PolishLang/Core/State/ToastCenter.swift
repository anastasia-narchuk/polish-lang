import Foundation
import Observation

/// Short messages at the bottom of the screen ("Добавлено: 3").
@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ text: String, seconds: Double = 2.5) {
        message = text
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
