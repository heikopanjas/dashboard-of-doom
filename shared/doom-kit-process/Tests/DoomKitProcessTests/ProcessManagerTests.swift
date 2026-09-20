import Foundation
import Testing

@testable import DoomKitProcess

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProcessManagerTests {
    @MainActor private final class ManualClock {
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

    @MainActor private final class Gate {
        let events = AsyncStream.makeStream(of: UUID.self)
        var pending: [UUID: CheckedContinuation<Void, Never>] = [:]

        func wait() async -> UUID {
            let id = UUID()
            await withCheckedContinuation { continuation in
                self.pending[id] = continuation
                self.events.continuation.yield(id)
            }
            return id
        }

        func release(_ id: UUID) { self.pending.removeValue(forKey: id)?.resume() }
    }

    @Test func registrationContextAndIndividualRefresh() async {
        let manager = ProcessManager<Int>()
        let id = UUID()
        var values: [Int] = []
        manager.register(id: id, interval: .seconds(60)) { values.append($0) }
        #expect(values.isEmpty == true)
        manager.updateContext(7)
        let first = manager.refresh(id: id)
        await first?.value
        #expect(values == [7])
        manager.updateContext(9)
        #expect(values == [7])
        await manager.refresh(id: id)?.value
        #expect(values == [7, 9])
        manager.remove(id: id)
        #expect(manager.refresh(id: id) == nil)
        manager.shutdown()
    }

    @Test func registrationReplacementRefreshesImmediately() async {
        let manager = ProcessManager<Int>(context: 1)
        let id = UUID()
        let events = AsyncStream.makeStream(of: String.self)
        var iterator = events.stream.makeAsyncIterator()
        manager.register(id: id, interval: .seconds(60)) { _ in events.continuation.yield("first") }
        #expect(await iterator.next() == "first")
        manager.register(id: id, interval: .seconds(60)) { _ in events.continuation.yield("replacement") }
        #expect(await iterator.next() == "replacement")
        await manager.refresh(id: id)?.value
        #expect(await iterator.next() == "replacement")
        manager.shutdown()
        events.continuation.finish()
    }

    @Test func cadenceMinimumIntervalAndBulkReset() async {
        let clock = ManualClock()
        let manager = ProcessManager<Int>(context: 1, clock: clock.clock)
        let events = AsyncStream.makeStream(of: Int.self)
        var iterator = events.stream.makeAsyncIterator()
        manager.register(interval: .seconds(1)) { events.continuation.yield($0) }
        #expect(await iterator.next() == 1)
        manager.start()
        await clock.waitForSleep()
        clock.advance(.seconds(59))
        await clock.waitForSleep()
        manager.updateContext(2)
        clock.advance(.seconds(1))
        #expect(await iterator.next() == 2)
        await clock.waitForSleep()
        clock.advance(.seconds(30))
        await clock.waitForSleep()
        manager.refreshAll()
        #expect(await iterator.next() == 2)
        clock.advance(.seconds(60))
        #expect(await iterator.next() == 2)
        manager.shutdown()
    }

    @Test func readinessStopAndRestart() async {
        let clock = ManualClock()
        let manager = ProcessManager<Int>(context: 1, clock: clock.clock)
        var count = 0
        let id = manager.register(interval: .seconds(60)) { _ in count += 1 }
        await manager.refresh(id: id)?.value
        let baseline = count
        manager.isReady = false
        manager.start()
        await clock.waitForSleep()
        clock.advance(.seconds(60))
        await clock.waitForSleep()
        #expect(count == baseline)
        manager.stop()
        #expect(manager.isRunning == false)
        #expect(manager.refresh(id: id) == nil)
        manager.isReady = true
        manager.start()
        await manager.refresh(id: id)?.value
        #expect(count == baseline + 1)
        manager.shutdown()
        manager.start()
        #expect(manager.refresh(id: id) == nil)
        manager.stop()
    }

    @Test func cancelledLateCompletionCannotPublishOrDisturbReplacement() async throws {
        let manager = ProcessManager<Int>()
        let gate = Gate()
        var iterator = gate.events.stream.makeAsyncIterator()
        var published: [Int] = []
        let id = manager.register(interval: .seconds(60)) { value in
            _ = await gate.wait()  // Deliberately ignores cancellation while suspended.
            guard Task.isCancelled == false else { return }
            published.append(value)
        }
        manager.updateContext(1)
        let first = manager.refresh(id: id)
        let firstID = try #require(await iterator.next())
        manager.updateContext(2)
        let replacement = manager.refresh(id: id)
        let replacementID = try #require(await iterator.next())
        gate.release(firstID)
        await first?.value
        #expect(published.isEmpty == true)
        // An obsolete completion must not remove the replacement's task handle.
        manager.remove(id: id)
        #expect(replacement?.isCancelled == true)
        gate.release(replacementID)
        await replacement?.value
        #expect(published.isEmpty == true)
        manager.shutdown()
    }

    @Test func repeatedRefreshCancelsAndRestarts() async throws {
        let manager = ProcessManager<Int>()
        let gate = Gate()
        var iterator = gate.events.stream.makeAsyncIterator()
        var published = 0
        let id = manager.register(interval: .seconds(60)) { _ in
            _ = await gate.wait()
            guard Task.isCancelled == false else { return }
            published += 1
        }
        manager.updateContext(1)
        let old = manager.refresh(id: id)
        let oldID = try #require(await iterator.next())
        let new = manager.refresh(id: id)
        let newID = try #require(await iterator.next())
        #expect(old?.isCancelled == true)
        gate.release(newID)
        await new?.value
        gate.release(oldID)
        await old?.value
        #expect(published == 1)
        manager.shutdown()
    }
    @Test func deinitializationCancelsOwnedWork() async throws {
        let clock = ManualClock()
        let gate = Gate()
        var iterator = gate.events.stream.makeAsyncIterator()
        var manager: ProcessManager<Int>? = ProcessManager(clock: clock.clock)
        let id = manager?.register(interval: .seconds(60)) { _ in _ = await gate.wait() }
        manager?.updateContext(1)
        let task = manager?.refresh(id: try #require(id))
        let pending = try #require(await iterator.next())
        manager?.start()
        await clock.waitForSleep()
        weak var weakManager = manager
        manager = nil
        #expect(weakManager == nil)
        #expect(task?.isCancelled == true)
        gate.release(pending)
        await task?.value
    }

}
