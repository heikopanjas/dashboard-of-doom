import Foundation

/// Somewhere to keep secrets, one string per key. `KeychainSecretStore` is the real one; `MemorySecretStore` stands in for tests and
/// previews.
public protocol SecretStore: Sendable {
    /// The stored value, or nil when there is none.
    func read(_ key: SecretKey) throws -> String?

    /// Stores the value, replacing any earlier one. An empty value is the same as deleting.
    func write(_ value: String, for key: SecretKey) throws

    /// Removes the value. Removing a value that is not there is not an error.
    func delete(_ key: SecretKey) throws
}

extension SecretStore {
    /// Whether a value is stored. Cheaper to read than the value when only its presence matters.
    public func contains(_ key: SecretKey) -> Bool {
        return ((try? self.read(key)) ?? nil) != nil
    }
}
