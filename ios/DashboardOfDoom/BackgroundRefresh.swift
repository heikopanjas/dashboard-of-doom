import BackgroundTasks
import DoomKitLocation
import DoomKitTools
import Foundation

/// Wakes the app now and then so warnings arrive while the phone lies still. Without it a background refresh only happens after a location
/// update of more than 100 metres. iOS decides when the task runs; the request only says not before `interval`.
@MainActor
enum BackgroundRefresh {
    /// Also listed under `BGTaskSchedulerPermittedIdentifiers` in Info.plist; the two must match.
    static let identifier = "com.panjas.dashboard-of-doom.refresh"
    static let interval: TimeInterval = 15 * 60
    /// How long a woken app waits for a measured position before refreshing anyway. The notifier stays silent on the fallback, so a refresh
    /// without one only updates the data.
    static let locationTimeout: Duration = .seconds(10)

    /// Must run before launch finishes.
    static func register() {
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: .main) { task in
            MainActor.assumeIsolated {
                guard let task = task as? BGAppRefreshTask else { return }
                Self.handle(task)
            }
        }
        if registered == false {
            trace.error("Background refresh could not be registered")
        }
    }

    /// Only worth the wake-ups while notifications are on; nothing else needs data the reader is not looking at.
    static func shouldSchedule(defaults: UserDefaults = .standard) -> Bool {
        return WarningPreferences.isEnabled(defaults: defaults)
    }

    /// Called on entering the background and when the master switch changes. A new request replaces a pending one.
    static func schedule(defaults: UserDefaults = .standard) {
        guard Self.shouldSchedule(defaults: defaults) == true else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.identifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        }
        catch {
            // The simulator always refuses; on a device this means background refresh is off for the app.
            trace.debug("Background refresh not scheduled: %@", error.localizedDescription)
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        Self.schedule()
        let work = Task { @MainActor in
            await Self.waitForMeasuredLocation()
            await AppProcess.shared.refreshSubscriptionsAndWait()
            guard Task.isCancelled == false else { return }
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private static func waitForMeasuredLocation() async {
        guard AppLocation.shared.state.origin != .measured else { return }
        let updates = AppLocation.shared.updates()
        let timeout = Self.locationTimeout
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await state in updates where state.origin == .measured { return }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
            }
            await group.next()
            group.cancelAll()
        }
    }
}
