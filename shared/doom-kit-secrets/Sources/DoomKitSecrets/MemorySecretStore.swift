import Foundation
import Synchronization

/// A store that keeps its secrets in memory and forgets them with the process, for tests and previews.
public final class MemorySecretStore: SecretStore {
    private let values = Mutex<[SecretKey: String]>([:])

    public init(_ values: [SecretKey: String] = [:]) {
        self.values.withLock { $0 = values }
    }

    public func read(_ key: SecretKey) throws -> String? {
        return self.values.withLock { $0[key] }
    }

    public func write(_ value: String, for key: SecretKey) throws {
        self.values.withLock { values in
            if value.isEmpty == true {
                values[key] = nil
            }
            else {
                values[key] = value
            }
        }
    }

    public func delete(_ key: SecretKey) throws {
        self.values.withLock { $0[key] = nil }
    }
}
