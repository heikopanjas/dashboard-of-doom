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

    /// Both apps keep loading every category for the nearest places row on the
    /// Home tab, so the switches only change the map.
    private var explainer: String {
        return "Marks these places within 6.7 km on the map; the switches change only the map, and the nearest of each still shows on the Home screen. The list refreshes every hour, or as soon as you move 1 km. Map data © OpenStreetMap contributors."
    }

    /// The master switch only clears the map, since every category keeps loading
    /// for the nearest places row.
    private var masterLabel: String {
        return "Show on map"
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
