import Foundation
import Security

/// Secrets in the keychain, as generic passwords under one service name, one account per key.
///
/// Items are synchronizable, so a key entered on one device reaches the others through iCloud Keychain, and they are readable after the
/// first unlock, so a refresh in the background can use them. The data protection keychain is asked for explicitly: on macOS that is what
/// syncs, and it is the one the sandboxed app has.
public final class KeychainSecretStore: SecretStore {
    public let service: String

    /// - Parameter service: What the items are filed under; the app's bundle identifier keeps them apart from anything else.
    public init(service: String) {
        self.service = service
    }

    public func read(_ key: SecretKey) throws -> String? {
        var query = Self.query(service: self.service, key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw SecretStoreError.keychain(status) }
        guard let data = result as? Data, let text = String(data: data, encoding: .utf8) else { throw SecretStoreError.notText }
        return text
    }

    public func write(_ value: String, for key: SecretKey) throws {
        if value.isEmpty == true {
            try self.delete(key)
            return
        }
        let data = Data(value.utf8)
        let query = Self.query(service: self.service, key: key)
        let update: [String: Any] = [kSecValueData as String: data]
        let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updated == errSecSuccess {
            return
        }
        guard updated == errSecItemNotFound else { throw SecretStoreError.keychain(updated) }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw SecretStoreError.keychain(added) }
    }

    public func delete(_ key: SecretKey) throws {
        let status = SecItemDelete(Self.query(service: self.service, key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretStoreError.keychain(status) }
    }

    /// The attributes that identify one secret's item. Every call starts from these, so read, write and delete agree on what an item is.
    static func query(service: String, key: SecretKey) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.name,
            kSecAttrSynchronizable as String: true,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}
