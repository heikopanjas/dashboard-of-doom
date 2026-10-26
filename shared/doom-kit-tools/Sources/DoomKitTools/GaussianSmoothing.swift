import Foundation

/// Converts neighbors to each output unit, normalizes edges, and clamps negative results.
public func gaussianSmoothing<T: Dimension>(data: [Measurement<T>], windowSize: Int = 5, sigma: Double = 1.0) -> [Measurement<T>] {
    guard data.isEmpty == false else { return [] }
    guard windowSize > 0, windowSize % 2 == 1, sigma > 0, sigma.isFinite == true else { return data }
    let count = data.count
    let radius = windowSize / 2

    // Precompute Gaussian weights
    let weights: [Double] = (0 ..< windowSize).map { i in
        let x = Double(i - radius)
        return exp(-x * x / (2 * sigma * sigma))
    }

    // Smooth each measurement
    var smoothed: [Measurement<T>] = []
    for i in 0 ..< count {
        var weightedSum = 0.0
        var localWeightSum = 0.0
        let unit = data[i].unit

        for j in -radius ... radius {
            let index = i + j
            if index >= 0 && index < count {
                let neighbor = data[index].converted(to: unit)
                let weight = weights[j + radius]
                weightedSum += neighbor.value * weight
                localWeightSum += weight
            }
        }

        let smoothedValue = weightedSum / localWeightSum
        let smoothedMeasurement = Measurement(value: smoothedValue > 0.0 ? smoothedValue : 0.0, unit: unit)

        smoothed.append(smoothedMeasurement)
    }

    return smoothed
}
