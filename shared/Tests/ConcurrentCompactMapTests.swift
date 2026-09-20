import Testing

@Suite struct ConcurrentCompactMapTests {
    private actor Gauge {
        private var running = 0
        private(set) var peak = 0

        func enter() {
            self.running += 1
            self.peak = max(self.peak, self.running)
        }

        func leave() {
            self.running -= 1
        }
    }

    @Test func keepsOrderDropsNilsAndBoundsConcurrency() async throws {
        let gauge = Gauge()
        let results = try await Array(0 ..< 8).concurrentCompactMap(limit: 2) { value in
            await gauge.enter()
            // The first element finishes last, so the order cannot be the completion order.
            try await Task.sleep(for: .milliseconds(value == 0 ? 80 : 5))
            await gauge.leave()
            return value % 3 == 0 ? nil : value * 10
        }
        let peak = await gauge.peak
        #expect(results == [10, 20, 40, 50, 70])
        #expect(peak == 2)
    }

    @Test func aLimitBelowOneStillRunsEverything() async throws {
        let results = try await [1, 2, 3].concurrentCompactMap(limit: 0) { value in
            return value
        }
        #expect(results == [1, 2, 3])
    }

    @Test func emptyInputReturnsEmpty() async throws {
        let results = try await [Int]().concurrentCompactMap(limit: 2) { value in
            return value
        }
        #expect(results.isEmpty == true)
    }

    @Test func aFailingTransformPropagates() async {
        struct Failure: Error {}
        await #expect(throws: Failure.self) {
            _ = try await [1, 2, 3].concurrentCompactMap(limit: 2) { value in
                if value == 2 { throw Failure() }
                return value
            }
        }
    }
}
