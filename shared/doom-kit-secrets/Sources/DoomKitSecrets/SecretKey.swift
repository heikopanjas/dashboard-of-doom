import Foundation

/// The name a secret is stored under, such as an API key or a token. A source declares one as a constant and reads it wherever it needs
/// the value, so the name is written in one place.
public struct SecretKey: Hashable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}
