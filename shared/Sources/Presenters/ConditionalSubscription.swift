import Foundation

/// Owns a source registration independently of the lifetime of any view.
@MainActor
final class ConditionalSubscription {
    private let defaultEnabled: Bool
    private let defaults: UserDefaults
    private let enableKey: String
    private let intervalKey: String
    private let fallback: TimeInterval
    private let register: @MainActor (TimeInterval) -> Void
    private let remove: @MainActor () -> Void
    private let notifications: NotificationCenter
    private var observer: NSObjectProtocol?
    private var isRegistered = false

    var isEnabled: Bool {
        return self.defaults.object(forKey: self.enableKey) as? Bool ?? self.defaultEnabled
    }

    init(
        defaults: UserDefaults, enableKey: String, intervalKey: String, fallback: TimeInterval,
        notifications: NotificationCenter = .default, defaultEnabled: Bool = true,
        register: @escaping @MainActor (TimeInterval) -> Void, remove: @escaping @MainActor () -> Void
    ) {
        self.defaultEnabled = defaultEnabled
        self.defaults = defaults
        self.enableKey = enableKey
        self.intervalKey = intervalKey
        self.fallback = fallback
        self.notifications = notifications
        self.register = register
        self.remove = remove
        self.observer = notifications.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reconcile()
            }
        }
        self.reconcile()
    }

    private func reconcile() -> Void {
        let enabled = self.isEnabled
        guard enabled != self.isRegistered else { return }
        self.isRegistered = enabled
        if enabled == true {
            let interval = self.defaults.integer(forKey: self.intervalKey)
            self.register(interval > 0 ? TimeInterval(interval) : self.fallback)
        }
        else {
            self.remove()
        }
    }

    isolated deinit {
        if let observer = self.observer {
            self.notifications.removeObserver(observer)
        }
        if self.isRegistered == true {
            self.remove()
        }
    }
}
