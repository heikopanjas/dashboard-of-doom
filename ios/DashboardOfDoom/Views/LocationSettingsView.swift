import DoomKitLocation
import SwiftUI

struct LocationSettingsView: View {
    @State private var state = AppLocation.shared.state

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                HStack {
                    Text("Access")
                    Spacer()
                    Text(self.accessValue)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text(self.detail)
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                HStack {
                    Button("Open iOS Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .task {
            for await state in AppLocation.shared.updates() {
                guard Task.isCancelled == false else { return }
                self.state = state
            }
        }
    }

    private var accessValue: String {
        switch self.state.authorization {
            case .denied: return "Denied"
            case .restricted: return "Restricted"
            case .notDetermined: return "Not Granted"
            case .authorized:
                switch self.state.authorizationScope {
                    case .always: return "Always"
                    case .whenInUse: return "While Using the App"
                    case .unknown: return "Allowed"
                }
        }
    }

    private var detail: String {
        let origin =
            self.state.origin == .fallback
            ? "Readings come from sensors near the default location, HKW in Berlin."
            : "Readings come from sensors near you."
        switch self.state.authorization {
            case .denied, .restricted, .notDetermined:
                return "\(origin) Allow location access to use where you actually are."
            case .authorized:
                switch self.state.authorizationScope {
                    case .always:
                        return "\(origin) They follow you as you move, even while the app is in the background."
                    default:
                        return "\(origin) Choose Always to keep them following you while the app is in the background."
                }
        }
    }
}
