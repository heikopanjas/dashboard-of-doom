import DoomKitTools
import Foundation
import UserNotifications

/// The app's side of `UNUserNotificationCenter`: asking for permission, posting notices, and showing them while the app is in front, which
/// the system does not do on its own. It is the center's delegate from launch.
final class NotificationCenterPoster: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationCenterPoster()

    private var center: UNUserNotificationCenter { return UNUserNotificationCenter.current() }

    /// Called at launch, before a notice can arrive. When notifications are already on, for instance switched on by a launch argument or
    /// restored from a backup, permission is asked here, since the settings switch that normally asks never moved.
    func activate(defaults: UserDefaults = .standard) {
        self.center.delegate = self
        guard WarningPreferences.isEnabled(defaults: defaults) == true else { return }
        Task { _ = await self.requestAuthorization() }
    }

    /// Asks once; later calls return what the user decided.
    func requestAuthorization() async -> Bool {
        do {
            return try await self.center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        catch {
            trace.error("Notification permission request failed: %@", error.localizedDescription)
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        return await self.center.notificationSettings().authorizationStatus
    }

    func post(_ notice: WarningNotice) {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body
        content.sound = .default
        content.threadIdentifier = notice.family.rawValue
        content.userInfo = ["family": notice.family.rawValue]
        // Time sensitive needs an entitlement the app does not have yet; without it the system delivers the notice as an active one.
        content.interruptionLevel = notice.level == .critical ? .timeSensitive : .active
        let request = UNNotificationRequest(identifier: notice.identifier, content: content, trigger: nil)
        trace.info("Posting notification %@: %@, %@", notice.identifier, notice.title, notice.body)
        self.center.add(request) { error in
            if let error {
                trace.error("Posting notification %@ failed: %@", notice.identifier, error.localizedDescription)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
