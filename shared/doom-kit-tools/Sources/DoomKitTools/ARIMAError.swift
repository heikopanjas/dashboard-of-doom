import Foundation

public enum ARIMAError: Error {
    case insufficientData
    case invalidParameters
    case convergenceFailure
    case invalidTimeInterval(expected: TimeInterval, found: TimeInterval)
}
