import Foundation

/// Holt's linear trend with a damped slope, ETS(A,Ad,N): a level and a slope, both corrected by every new value, with the slope fading
/// by `phi` per step, so a forecast bends towards a plateau instead of running off in a straight line. The band widens with the horizon
/// by the model's own variance formula.
public struct DampedTrendModel: ForecastModel {
    public struct Parameters: Sendable, Equatable {
        /// How much of each surprise goes into the level.
        public let alpha: Double
        /// How much goes into the slope.
        public let beta: Double
        /// How much of the slope survives each step.
        public let phi: Double

        public init(alpha: Double, beta: Double, phi: Double) {
            self.alpha = alpha
            self.beta = beta
            self.phi = phi
        }
    }

    /// The fitted state at the end of the series.
    public struct Fit: Sendable, Equatable {
        public let parameters: Parameters
        public let level: Double
        public let slope: Double
        /// The spread of the one-step errors.
        public let sigma: Double
    }

    /// Fixed parameters, or nil to fit them to each series.
    public let parameters: Parameters?

    public init(parameters: Parameters? = nil) {
        self.parameters = parameters
    }

    public var name: String {
        return "trend"
    }

    public var minimumHistory: Int {
        return 4
    }

    public func predict(_ values: [Double], horizon: Int, coverage: Double) throws -> [ForecastInterval] {
        let fit = try self.fit(values)
        let z = Statistics.z(coverage: coverage)
        let (alpha, beta, phi) = (fit.parameters.alpha, fit.parameters.beta, fit.parameters.phi)
        var damped = 0.0  // phi + phi^2 + ... + phi^h
        var variance = 0.0  // sum over j < h of (alpha + beta * (phi + ... + phi^j))^2
        var intervals: [ForecastInterval] = []
        for h in 1 ... max(horizon, 1) {
            if h > 1 {
                let c = alpha + beta * damped
                variance += c * c
            }
            damped += pow(phi, Double(h))
            let mean = fit.level + damped * fit.slope
            let half = z * fit.sigma * sqrt(1 + variance)
            intervals.append(ForecastInterval(mean: mean, lower: mean - half, upper: mean + half))
        }
        return intervals
    }

    /// The fitted state: the given parameters, or those with the smallest one-step error on a grid.
    public func fit(_ values: [Double]) throws -> Fit {
        guard values.count >= self.minimumHistory, values.allSatisfy({ $0.isFinite }) else { throw ForecastError.insufficientData }
        if let parameters = self.parameters {
            return Self.run(values, parameters: parameters).fit
        }
        var best: (fit: Fit, error: Double)?
        for alpha in stride(from: 0.05, through: 0.95, by: 0.05) {
            for beta in [0.01, 0.05, 0.1, 0.2, 0.3] where beta <= alpha {
                for phi in [0.8, 0.85, 0.9, 0.95, 0.98] {
                    let result = Self.run(values, parameters: Parameters(alpha: alpha, beta: beta, phi: phi))
                    if result.error < (best?.error ?? .infinity) { best = result }
                }
            }
        }
        guard let best else { throw ForecastError.insufficientData }
        return best.fit
    }

    /// The error-correction recursion over the series, from a level at the first value and a slope from the first few steps.
    private static func run(_ values: [Double], parameters: Parameters) -> (fit: Fit, error: Double) {
        let (alpha, beta, phi) = (parameters.alpha, parameters.beta, parameters.phi)
        let start = min(4, values.count - 1)
        var level = values[0]
        var slope = (values[start] - values[0]) / Double(start)
        var squares = 0.0
        for value in values.dropFirst() {
            let expected = level + phi * slope
            let error = value - expected
            squares += error * error
            level = expected + alpha * error
            slope = phi * slope + beta * error
        }
        let sigma = sqrt(squares / Double(max(values.count - 1, 1)))
        return (Fit(parameters: parameters, level: level, slope: slope, sigma: sigma), squares)
    }
}
