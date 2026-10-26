import Foundation

/// App-owned lifecycle: background location continues, foreground return refreshes once.
@MainActor
final class AppActivityLifecycle {
    private let startWork: () -> Void
    private let refreshWork: () -> Void
    private var started = false
    private var wasBackgrounded = false

    init(start: @escaping () -> Void, refresh: @escaping () -> Void) {
        self.startWork = start
        self.refreshWork = refresh
    }

    func start() {
        guard self.started == false else { return }
        self.started = true
        self.startWork()
    }

    func enteredBackground() {
        self.wasBackgrounded = true
    }

    func becameActive() {
        self.start()
        guard self.wasBackgrounded == true else { return }
        self.wasBackgrounded = false
        self.refreshWork()
    }
}
