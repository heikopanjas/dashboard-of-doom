import SwiftUI

struct ActivityIndicator: View {
    var body: some View {
        VStack {
            HStack {
                Text("No data available")
                Spacer()
            }
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
            Spacer()
        }
    }
}
