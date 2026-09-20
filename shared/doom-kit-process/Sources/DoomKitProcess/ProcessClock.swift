/// Monotonic time and cancellation-cooperative sleeping, injectable for tests.
@MainActor
public struct ProcessClock {
    public let now: @MainActor () -> Duration
    public let sleep: @MainActor (Duration) async throws -> Void

    public init(
        now: @escaping @MainActor () -> Duration,
        sleep: @escaping @MainActor (Duration) async throws -> Void
    ) {
        self.now = now
        self.sleep = sleep
    }

    public static var continuous: Self {
        let clock = ContinuousClock()
        let origin = clock.now
        return Self(
            now: { return origin.duration(to: clock.now) },
            sleep: { duration in try await clock.sleep(for: duration) })
    }
}
