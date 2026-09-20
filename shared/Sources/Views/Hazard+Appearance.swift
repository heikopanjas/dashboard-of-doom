import SwiftUI

extension Hazard.Severity {
    /// The DWD warning scale. Green is not used, so the all-clear state keeps it.
    var color: Color {
        switch self {
            case .unknown: return .gray
            case .minor: return .yellow
            case .moderate: return .orange
            case .severe: return .red
            case .extreme: return .purple
        }
    }
}
