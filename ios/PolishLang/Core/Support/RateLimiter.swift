import Foundation

/// Sliding-window limit on requests (TZ 2, section 7: 5 generations and 30 translations a minute).
struct RateLimiter: Sendable {
    let limit: Int
    let window: TimeInterval
    private(set) var stamps: [Date] = []

    init(limit: Int, window: TimeInterval = 60) {
        self.limit = limit
        self.window = window
    }

    /// Records the call and returns nil if it is allowed, or the seconds to wait otherwise.
    mutating func acquire(now: Date = Date()) -> TimeInterval? {
        stamps.removeAll { now.timeIntervalSince($0) >= window }
        guard stamps.count >= limit else {
            stamps.append(now)
            return nil
        }
        let oldest = stamps.min() ?? now
        return max(1, (window - now.timeIntervalSince(oldest)).rounded(.up))
    }
}
