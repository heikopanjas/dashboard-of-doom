extension Array {
    /// Transforms the elements with at most `limit` transforms in flight. The result keeps the order of the array, whatever order the
    /// transforms finish in, and leaves out the elements whose transform returns nil.
    func concurrentCompactMap<Result>(limit: Int, _ transform: @escaping (Element) async throws -> Result?) async throws -> [Result] {
        return try await withThrowingTaskGroup(of: (Int, Result?).self) { group in
            var iterator = self.enumerated().makeIterator()
            func submit(_ entry: (offset: Int, element: Element)) -> Void {
                group.addTask {
                    try Task.checkCancellation()
                    return (entry.offset, try await transform(entry.element))
                }
            }
            for _ in 0 ..< Swift.max(limit, 1) {
                if let next = iterator.next() {
                    submit(next)
                }
            }
            var results: [(offset: Int, value: Result)] = []
            for try await (offset, value) in group {
                if let value = value {
                    results.append((offset: offset, value: value))
                }
                if Task.isCancelled == false, let next = iterator.next() {
                    submit(next)
                }
            }
            return results.sorted { $0.offset < $1.offset }.map { $0.value }
        }
    }
}
