import Foundation

/// One step of a model's prediction: the expected value and the band that holds the true value with the requested coverage.
public struct ForecastInterval: Sendable, Equatable {
    public let mean: Double
    public let lower: Double
    public let upper: Double

    public init(mean: Double, lower: Double, upper: Double) {
        self.mean = mean
        self.lower = lower
        self.upper = upper
    }
}

/// A predicted value at a time, back in the series' own scale.
public struct ForecastPoint: Sendable, Equatable {
    public let timestamp: Date
    public let value: Double
    public let lower: Double
    public let upper: Double

    public init(timestamp: Date, value: Double, lower: Double, upper: Double) {
        self.timestamp = timestamp
        self.value = value
        self.lower = lower
        self.upper = upper
    }
}

/// The scale a model works in. Prices move in proportion to their level and cannot go below zero, so they are forecast as logarithms;
/// counts can be zero, so they take the logarithm of one more. Both give a band that is wider above than below.
public enum ForecastTransform: Sendable {
    case identity
    case logarithm
    case logarithmPlusOne

    func forward(_ value: Double) -> Double {
        switch self {
            case .identity: return value
            case .logarithm: return value > 0 ? log(value) : .nan
            case .logarithmPlusOne: return value > -1 ? log1p(value) : .nan
        }
    }

    func backward(_ value: Double) -> Double {
        switch self {
            case .identity: return value
            case .logarithm: return exp(value)
            case .logarithmPlusOne: return expm1(value)
        }
    }
}

public enum ForecastError: Error, Equatable {
    /// Fewer values than the model needs.
    case insufficientData
    /// A value the transform cannot take, such as zero for a logarithm.
    case nonFinite
}

/// What to forecast: how far apart the values are, how many steps ahead, and how.
public struct ForecastRequest: Sendable {
    /// The spacing of the regular grid the history is put on, and of the forecast.
    public var step: TimeInterval
    /// Steps ahead.
    public var horizon: Int
    /// The share of outcomes the band should hold; 0.8 matches the 10 to 90 percentiles a provider such as PEGELONLINE publishes.
    public var coverage: Double
    /// Values outside can not happen, such as a poll share outside 0 to 100; the forecast and its band are clamped to them.
    public var bounds: ClosedRange<Double>?
    public var transform: ForecastTransform
    /// A gap in the history longer than this ends it: only what follows the gap is used, rather than a straight line across it.
    public var maximumGap: TimeInterval?

    public init(
        step: TimeInterval, horizon: Int, coverage: Double = 0.8, bounds: ClosedRange<Double>? = nil, transform: ForecastTransform = .identity,
        maximumGap: TimeInterval? = nil
    ) {
        self.step = step
        self.horizon = horizon
        self.coverage = coverage
        self.bounds = bounds
        self.transform = transform
        self.maximumGap = maximumGap
    }
}

/// A way of predicting an evenly spaced series. It sees plain values, oldest first, already on the grid and in the transformed scale;
/// `Forecaster` does the rest.
public protocol ForecastModel: Sendable {
    /// The method as a reader would call it, "trend" or "tide", for the label that says the forecast is the app's own.
    var name: String { get }
    var minimumHistory: Int { get }
    func predict(_ values: [Double], horizon: Int, coverage: Double) throws -> [ForecastInterval]
}
