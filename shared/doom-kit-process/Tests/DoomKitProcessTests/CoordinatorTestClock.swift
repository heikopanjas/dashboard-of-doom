import Foundation
import DoomKitProcess
@MainActor final class CoordinatorTestClock {
        var time: Duration = .zero
        var sleepers: [UUID: CheckedContinuation<Void, any Error>] = [:]
        var observers: [CheckedContinuation<Void, Never>] = []

        var clock: ProcessClock {
            return ProcessClock(now: { self.time }, sleep: { _ in try await self.sleep() })
        }

        func sleep() async throws {
            let id = UUID()
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await withCheckedThrowingContinuation { continuation in
                    self.sleepers[id] = continuation
                    for observer in self.observers { observer.resume() }
                    self.observers.removeAll()
                }
            } onCancel: {
                Task { @MainActor in self.sleepers.removeValue(forKey: id)?.resume(throwing: CancellationError()) }
            }
        }

        func waitForSleep() async {
            if self.sleepers.isEmpty == false { return }
            await withCheckedContinuation { self.observers.append($0) }
        }

        func advance(_ duration: Duration) {
            self.time += duration
            let sleepers = self.sleepers
            self.sleepers.removeAll()
            for sleeper in sleepers.values { sleeper.resume() }
        }
    }
