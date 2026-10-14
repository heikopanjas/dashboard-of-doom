import SwiftUI

/// Keep source buttons interactive while their sources are off, so they can still be customized.
struct DashboardToolbar: View {
    @Binding var selected: IOSScreen
    @Binding var storedConfiguration: String
    let available: Set<IOSScreen>
    @State private var accessibleSlot: Int?
    @State private var showsAccessibleChoices = false

    private var configuration: IOSToolbarConfiguration {
        return IOSToolbarConfiguration(storedValue: self.storedConfiguration)
    }

    var body: some View {
        HStack(spacing: 0) {
            self.button(.home, identifier: "toolbar.home")
            self.button(.weather, identifier: "toolbar.weather")
            ForEach(self.configuration.screens.indices, id: \.self) { slot in
                let screen = self.configuration.screens[slot]
                self.button(screen, identifier: "toolbar.slot.\(slot)")
                    .contextMenu {
                        self.choices(for: slot)
                    }
                    .accessibilityHint("Long press to choose a screen")
                    .accessibilityAction(named: "Customize") {
                        self.accessibleSlot = slot
                        self.showsAccessibleChoices = true
                    }
            }
            self.button(.settings, identifier: "toolbar.settings")
        }
        .confirmationDialog("Choose a screen", isPresented: self.$showsAccessibleChoices, titleVisibility: .visible) {
            if let slot = self.accessibleSlot {
                self.choices(for: slot)
            }
        }
    }

    private func button(_ screen: IOSScreen, identifier: String) -> some View {
        let enabled = self.available.contains(screen)
        let selected = self.selected == screen
        let opacity: Double
        if enabled == false {
            opacity = 0.2
        }
        else {
            opacity = selected == true ? 1 : 0.5
        }
        return Button {
            if enabled == true {
                self.selected = screen
            }
        } label: {
            Label(screen.label, systemImage: screen.symbol(selected: selected))
                .labelStyle(.iconOnly)
                .fontWeight(selected == true || screen == .particles ? .bold : .regular)
                .foregroundStyle(Color.accentColor.opacity(opacity))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(enabled == true ? "" : "Source off")
        .accessibilityAddTraits(selected == true ? [.isSelected] : [])
    }

    @ViewBuilder
    private func choices(for slot: Int) -> some View {
        ForEach(IOSScreen.customizable, id: \.self) { screen in
            Button {
                self.assign(screen, to: slot)
            } label: {
                if self.configuration.screens[slot] == screen {
                    Label(screen.label, systemImage: "checkmark")
                }
                else {
                    Text(screen.label)
                }
            }
            .accessibilityIdentifier("toolbar.choice.\(screen.rawValue)")
        }
    }

    private func assign(_ screen: IOSScreen, to slot: Int) -> Void {
        var configuration = self.configuration
        self.selected = configuration.assign(screen, to: slot, selected: self.selected, enabled: self.available.contains(screen))
        self.storedConfiguration = configuration.storedValue
    }
}
