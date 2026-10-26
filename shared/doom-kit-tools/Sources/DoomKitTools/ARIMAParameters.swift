import Foundation

public struct ARIMAParameters {
    public let p: Int  // Auto-regression order
    public let d: Int  // Difference order
    public let q: Int  // Moving average order

    public init(p: Int = 1, d: Int = 1, q: Int = 1) {
        self.p = max(0, p)
        self.d = max(0, d)
        self.q = max(0, q)
    }
}
