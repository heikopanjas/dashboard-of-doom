import UIKit

@MainActor
final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    let runtime = IOSAppRuntime()

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Both have to be in place before launch finishes: the delegate before a notice arrives, the task before iOS asks for it.
        NotificationCenterPoster.shared.activate()
        BackgroundRefresh.register()
        self.runtime.lifecycle.start()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.runtime.lifecycle.enteredBackground()
        BackgroundRefresh.schedule()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        self.runtime.lifecycle.becameActive()
    }
}
