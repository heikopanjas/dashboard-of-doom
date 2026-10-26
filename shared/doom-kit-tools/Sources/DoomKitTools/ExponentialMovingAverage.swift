import Foundation

/// Uses raw values and the first unit, matching the original smoothing API.
public func exponentialMovingAverage<T: Dimension>(data: [Measurement<T>], alpha: Double) -> [Measurement<T>] {
    guard data.isEmpty == false else { return [] }
    let unit = data[0].unit
    var previousValue = data[0].value
    var smoothed = [Measurement(value: previousValue, unit: unit)]
    for current in data.dropFirst() {
        let ema = alpha * current.value + (1 - alpha) * previousValue
        previousValue = ema
        smoothed.append(Measurement(value: ema, unit: unit))
    }
    return smoothed
}
