import Foundation

/// Words in the reader are links with a private scheme; a tap opens `plword://<token id>`
/// and the reader turns it back into the token (the text itself is never parsed as markup).
enum ReaderLink {
    static let scheme = "plword"

    static func url(for tokenID: Int) -> URL? {
        URL(string: "\(scheme)://\(tokenID)")
    }

    static func tokenID(from url: URL) -> Int? {
        guard url.scheme == scheme else { return nil }
        return Int(url.absoluteString.dropFirst(scheme.count + 3))
    }
}
