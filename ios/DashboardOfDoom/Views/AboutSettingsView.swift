import SwiftUI

/// The About section at the end of Settings: the version, what the warnings are not, and every data source with the credit its licence
/// asks for, the same list the macOS About tab shows.
struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    Spacer()
                }
                HStack {
                    Text(DataSources.disclaimer)
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                Divider()
                DataSourceList()
                Divider()
                HStack {
                    Text("© 2025 Heiko Panjas. All rights reserved.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}
