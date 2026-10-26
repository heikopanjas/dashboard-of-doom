import DoomKitSecrets
import DoomKitTools
import Foundation

/// The app's secrets: API keys and tokens in the keychain, synced through iCloud Keychain. A source declares its `SecretKey` next to its
/// service and reads it here. Nothing reads a key yet; this is where one goes when a source needs it.
enum AppSecrets {
    static let shared: any SecretStore = KeychainSecretStore(service: "com.panjas.dashboard-of-doom.secrets")

    #if DEBUG
    /// The keychain only works in an entitled process, which the unsigned test runners are not, so `--keychain-check` proves it in the app
    /// itself: a probe key is written, read back, replaced and removed, and the outcome is traced.
    static func runSelfCheckIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Void {
        guard arguments.contains("--keychain-check") == true else { return }
        let probe = SecretKey(name: "keychain-check-probe")
        do {
            try Self.shared.write("first", for: probe)
            let first = try Self.shared.read(probe)
            try Self.shared.write("second", for: probe)
            let second = try Self.shared.read(probe)
            try Self.shared.delete(probe)
            let gone = try Self.shared.read(probe)
            if first == "first" && second == "second" && gone == nil {
                trace.info("Keychain check passed: wrote, replaced and removed a probe key")
            }
            else {
                trace.error("Keychain check failed: read \(first ?? "nil"), \(second ?? "nil"), \(gone ?? "nil")")
            }
        }
        catch {
            trace.error("Keychain check failed: \(error)")
        }
    }
    #endif
}
