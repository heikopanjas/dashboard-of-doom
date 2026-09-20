import Foundation

public enum SecretStoreError: Error, Equatable {
    /// The keychain answered with a status other than success or not found.
    case keychain(OSStatus)
    /// The stored bytes were not UTF-8 text.
    case notText
}
