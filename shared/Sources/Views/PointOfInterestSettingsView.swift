import SwiftUI

struct PointOfInterestSettingsView: View {
    let presenter: PointOfInterestPresenter

    var body: some View {
        #if os(macOS)
        Form { self.controls }.formStyle(.grouped)
        #else
        VStack(alignment: .leading, spacing: 12) { self.controls }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        #endif
    }

    /// iOS keeps loading every category for the nearest places row, so its
    /// switches only change the map; macOS stops fetching what is switched off.
    private var explainer: String {
        #if os(iOS)
        return "Marks these places within 6.7 km on the map; the switches change only the map, and the nearest of each still shows on the Home screen. The list refreshes every hour, or as soon as you move 1 km. Map data © OpenStreetMap contributors."
        #else
        return "Marks these places within 6.7 km on the map. The list refreshes every hour, or as soon as you move 1 km. Map data © OpenStreetMap contributors."
        #endif
    }

    /// iOS keeps loading every category for the nearest places row, so the master
    /// switch only clears the map; macOS still stops fetching with it.
    private var masterLabel: String {
        #if os(iOS)
        return "Show on map"
        #else
        return "Show points of interest"
        #endif
    }

    private var controls: some View {
        Group {
            Toggle(
                self.masterLabel,
                isOn: Binding(
                    get: { self.presenter.isEnabled }, set: { self.presenter.setEnabled($0) }))
            ForEach(PointOfInterestCategory.allCases, id: \.self) { category in
                Toggle(
                    isOn: Binding(
                        get: { self.presenter.categories.contains(category) },
                        set: { self.presenter.setCategory(category, enabled: $0) })
                ) {
                    Label {
                        Text(category.title)
                    } icon: {
                        Image(systemName: category.symbol).foregroundStyle(category.color)
                    }
                }
                .disabled(self.presenter.isEnabled == false)
            }
            Text(self.explainer)
                .font(.caption).foregroundStyle(.secondary)
        }

    }
}
