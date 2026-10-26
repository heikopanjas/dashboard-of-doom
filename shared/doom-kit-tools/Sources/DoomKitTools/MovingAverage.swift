import Foundation

/// Uses raw values and the first unit, matching the original smoothing API.
public func movingAverage<T: Dimension>(data: [Measurement<T>], windowSize: Int) -> [Measurement<T>] {
    guard data.isEmpty == false else { return [] }
    guard windowSize > 0 else { return data }
    let unit = data[0].unit
    return data.indices.map { i in
        let start = max(0, i - windowSize + 1)
        let window = data[start ... i]
        let average = window.map { $0.value }.reduce(0.0, +) / Double(window.count)
        return Measurement(value: average, unit: unit)
    }
}
