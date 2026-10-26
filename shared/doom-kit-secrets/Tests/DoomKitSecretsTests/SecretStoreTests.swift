import Foundation
import Security
import Testing

@testable import DoomKitSecrets

@Suite struct SecretStoreTests {
    private let eia = SecretKey(name: "eia-api-key")
    private let fuel = SecretKey(name: "tankerkoenig-api-key")

    @Test func aMemoryStoreKeepsSeveralKeysApart() throws {
        let store = MemorySecretStore()
        #expect(try store.read(self.eia) == nil)
        #expect(store.contains(self.eia) == false)
        try store.write("abc", for: self.eia)
        try store.write("xyz", for: self.fuel)
        #expect(try store.read(self.eia) == "abc")
        #expect(try store.read(self.fuel) == "xyz")
        #expect(store.contains(self.fuel) == true)
        try store.write("def", for: self.eia)
        #expect(try store.read(self.eia) == "def")
        #expect(try store.read(self.fuel) == "xyz")
    }

    @Test func deletingAndWritingEmptyBothRemoveAndNeverFail() throws {
        let store = MemorySecretStore([self.eia: "abc", self.fuel: "xyz"])
        try store.delete(self.eia)
        #expect(try store.read(self.eia) == nil)
        try store.delete(self.eia)
        try store.write("", for: self.fuel)
        #expect(try store.read(self.fuel) == nil)
        #expect(store.contains(self.fuel) == false)
    }

    @Test func keysAreTheirNames() {
        #expect(SecretKey(name: "a") == SecretKey(name: "a"))
        #expect(SecretKey(name: "a") != SecretKey(name: "b"))
        #expect(Set([SecretKey(name: "a"), SecretKey(name: "a")]).count == 1)
    }

    @Test func theKeychainItemIsASyncedGenericPasswordFiledUnderTheServiceAndKey() {
        let query = KeychainSecretStore.query(service: "com.example.app", key: self.eia)
        #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrService as String] as? String == "com.example.app")
        #expect(query[kSecAttrAccount as String] as? String == "eia-api-key")
        #expect(query[kSecAttrSynchronizable as String] as? Bool == true)
        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
        // Identity only: what is returned or stored is added per call, so the three calls agree on which item they mean.
        #expect(query[kSecValueData as String] == nil)
        #expect(query[kSecReturnData as String] == nil)
    }

    @Test func theRealStoreIsSendableAndRemembersItsService() {
        let store = KeychainSecretStore(service: "com.example.app")
        #expect(store.service == "com.example.app")
        let _: any SecretStore = store
    }
}
