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

    private var controls: some View {
        Group {
            Toggle(
                "Show points of interest",
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
            Text("Marks these places within 6.7 km on the map. The list refreshes every hour, or as soon as you move 1 km. Map data © OpenStreetMap contributors.")
                .font(.caption).foregroundStyle(.secondary)
        }

    }
}
