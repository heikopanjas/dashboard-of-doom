import SwiftUI

/// A gray footnote under a chart saying what its series is, inset like a card but without one.
struct EnergyExplainerText: View {
    let text: String

    var body: some View {
        HStack {
            Text(self.text)
                .font(.footnote)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }
}
