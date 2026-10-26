import SwiftUI

/// "SIM · Dresden" in orange next to the app title while a place is simulated, the counterpart of the orange SIM tag in the macOS menu
/// bar. A tap offers to stop the simulation.
struct SimulationCapsule: View {
    let name: String?
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 4) {
                Text(verbatim: "SIM")
                    .fontWeight(.bold)
                if let name = self.name {
                    Text(verbatim: "·")
                    Text(name)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.orange))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(self.name.map { "Simulated location, \($0)" } ?? "Simulated location")
        .accessibilityHint("Offers to stop the simulation")
    }
}
