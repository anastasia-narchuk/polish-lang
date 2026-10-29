import Foundation

/// Where the API key is kept. The app uses the Keychain (`KeychainStore`); tests keep it in memory.
protocol SecretStore {
    func read(_ account: String) -> String?
    @discardableResult func save(_ value: String, account: String) -> Bool
    func delete(_ account: String)
}

final class InMemorySecretStore: SecretStore {
    private var values: [String: String] = [:]

    func read(_ account: String) -> String? {
        values[account]
    }

    @discardableResult
    func save(_ value: String, account: String) -> Bool {
        values[account] = value
        return true
    }

    func delete(_ account: String) {
        values[account] = nil
    }
}
