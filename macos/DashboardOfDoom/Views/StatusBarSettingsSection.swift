import SwiftUI

/// The Menu Bar section of Settings > General: every value of every source that is on, with its current reading and a checkbox. At most
/// two can be ticked, as in senor-particle's Devices settings; with none ticked the status item shows the temperature.
struct StatusBarSettingsSection: View {
    let faceplate: (StatusBarValue) -> String?

    // The selection is an array, which @AppStorage cannot hold, so the section keeps its own copy and writes through the preferences.
    @State private var selection = StatusBarPreferences.selection()

    // Observed so that a source switched off or on redraws the list here at once.
    @AppStorage(SourcePreferences.covidEnableKey) private var covid: Bool = SourcePreferences.covidEnabledByDefault
    @AppStorage(SourcePreferences.waterKey) private var water: Bool = true
    @AppStorage(SourcePreferences.radiationKey) private var radiation: Bool = true
    @AppStorage(SourcePreferences.particlesKey) private var particles: Bool = true
    @AppStorage(SourcePreferences.energyEnableKey) private var energy: Bool = SourcePreferences.energyEnabledByDefault

    var body: some View {
        let _ = [self.covid, self.water, self.radiation, self.particles, self.energy]
        Section {
            ForEach(StatusBarValue.Source.allCases.filter { $0.isAvailable() }, id: \.self) { source in
                ForEach(StatusBarValue.values(of: source), id: \.self) { value in
                    Toggle(isOn: self.binding(for: value)) {
                        HStack {
                            Label(value.label, systemImage: source.symbol)
                            Spacer()
                            Text(self.faceplate(value) ?? "—")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(self.selection.contains(value) == false && self.selection.count >= StatusBarPreferences.maximum)
                }
            }
            Text("Up to two values, from any source. With none ticked, the menu bar shows the temperature; a value whose source is switched off is left out.")
                .font(.footnote)
                .foregroundColor(.gray)
        } header: {
            Text("Menu Bar")
        }
    }

    private func binding(for value: StatusBarValue) -> Binding<Bool> {
        return Binding(
            get: { self.selection.contains(value) },
            set: { _ in
                StatusBarPreferences.toggle(value)
                self.selection = StatusBarPreferences.selection()
            })
    }
}
