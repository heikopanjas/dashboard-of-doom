import Foundation

@MainActor
public final class ProcessManager<Context: Sendable> {
    public typealias Refresh = @MainActor (Context) async -> Void

    private struct Registration: Sendable {
        var interval: Duration
        var deadline: Duration
        var action: Refresh
        var generation = UUID()
        var task: Task<Void, Never>?
    }

    var registrationCount: Int { return self.registrations.count }

    private let clock: ProcessClock
    private let cadence: Duration
    private var context: Context?
    private var registrations: [UUID: Registration] = [:]
    private var schedulingTask: Task<Void, Never>?
    private var lifecycle = UUID()
    private var enabled = true
    public private(set) var isRunning = false
    public var isReady = true

    public init(context: Context? = nil, cadence: Duration = .seconds(60), clock: ProcessClock = .continuous) {
        self.context = context
        self.cadence = max(.seconds(60), cadence)
        self.clock = clock
    }

    /// Replaces an existing registration, cancelling its work, and refreshes now.
    @discardableResult
    public func register(id: UUID = UUID(), interval: Duration, action: @escaping Refresh) -> UUID {
        self.remove(id: id)
        let interval = max(.seconds(60), interval)
        self.registrations[id] = Registration(interval: interval, deadline: self.clock.now() + interval, action: action)
        self.refresh(id: id)
        return id
    }

    public func remove(id: UUID) {
        self.registrations.removeValue(forKey: id)?.task?.cancel()
    }

    /// Context changes invalidate in-flight work without triggering a bulk refresh.
    public func updateContext(_ context: Context?) {
        self.context = context
        self.cancelRefreshes()
    }

    @discardableResult
    public func refresh(id: UUID) -> Task<Void, Never>? {
        guard self.enabled == true, let context = self.context, var registration = self.registrations[id] else { return nil }
        registration.task?.cancel()
        let generation = UUID()
        let action = registration.action
        registration.generation = generation
        let task = Task { [weak self] in
            guard Task.isCancelled == false else { return }
            await action(context)
            self?.complete(id: id, generation: generation)
        }
        registration.task = task
        self.registrations[id] = registration
        return task
    }

    /// Bulk refresh resets interval deadlines; individual refresh preserves them.
    public func refreshAll() {
        for id in Array(self.registrations.keys) { self.refresh(id: id) }
        self.resetIntervals()
    }

    public func resetIntervals() {
        let now = self.clock.now()
        for id in Array(self.registrations.keys) {
            if let interval = self.registrations[id]?.interval {
                self.registrations[id]?.deadline = now + interval
            }
        }
    }

    func resumeRefreshes() {
        self.enabled = true
    }

    public func start() {
        guard self.isRunning == false else { return }
        self.enabled = true
        self.isRunning = true
        let lifecycle = UUID()
        self.lifecycle = lifecycle
        let clock = self.clock
        let cadence = self.cadence
        self.schedulingTask = Task { [weak self] in
            while Task.isCancelled == false {
                do { try await clock.sleep(cadence) }
                catch { return }
                guard Task.isCancelled == false else { return }
                self?.tick(lifecycle: lifecycle)
            }
        }
    }

    public func stop() {
        self.enabled = false
        self.isRunning = false
        self.lifecycle = UUID()
        self.schedulingTask?.cancel()
        self.schedulingTask = nil
        self.cancelRefreshes()
    }

    /// Stop retains registrations for restart; shutdown removes them.
    public func shutdown() {
        self.stop()
        self.registrations.removeAll()
        self.context = nil
    }

    private func tick(lifecycle: UUID) {
        guard self.lifecycle == lifecycle, self.isReady == true else { return }
        let now = self.clock.now()
        for id in Array(self.registrations.keys) {
            guard let registration = self.registrations[id], registration.deadline <= now else { continue }
            self.refresh(id: id)
            self.registrations[id]?.deadline = now + registration.interval
        }
    }

    private func complete(id: UUID, generation: UUID) {
        guard self.registrations[id]?.generation == generation else { return }
        self.registrations[id]?.task = nil
    }

    private func cancelRefreshes() {
        for id in Array(self.registrations.keys) {
            self.registrations[id]?.task?.cancel()
            self.registrations[id]?.task = nil
            self.registrations[id]?.generation = UUID()
        }
    }

    deinit {
        self.schedulingTask?.cancel()
        for registration in self.registrations.values { registration.task?.cancel() }
    }
}
