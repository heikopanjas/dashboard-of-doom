import DoomKitProcess
import SwiftUI
import UserNotifications

/// The Notifications settings tab: the master switch, then a section per family with its switch and limits.
struct NotificationSettingsView: View {
    let levelPresenter: LevelPresenter

    @Environment(\.openURL) private var openURL
    @AppStorage(WarningPreferences.enabledKey) private var enabled: Bool = false
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Notify When a Reading Reaches a Limit", isOn: $enabled)
                    .onChange(of: enabled) { _, isOn in
                        guard isOn == true else { return }
                        Task {
                            _ = await NotificationCenterPoster.shared.requestAuthorization()
                            self.status = await NotificationCenterPoster.shared.authorizationStatus()
                        }
                    }
                Text("Once for the warning limit and once for the critical limit. Nothing is sent about the Berlin fallback location.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                if self.enabled == true && self.status == .denied {
                    HStack {
                        Text("Notifications are off for this app in System Settings.")
                            .font(.footnote)
                            .foregroundColor(.red)
                        Spacer()
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                self.openURL(url)
                            }
                        }
                    }
                }
            }
            if self.enabled == true {
                ForEach(WarningFamily.allCases, id: \.self) { family in
                    FamilySection(family: family, levelPresenter: self.levelPresenter)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task {
            self.status = await NotificationCenterPoster.shared.authorizationStatus()
        }
    }
}

private struct FamilySection: View {
    let family: WarningFamily
    let levelPresenter: LevelPresenter
    @AppStorage private var isOn: Bool

    init(family: WarningFamily, levelPresenter: LevelPresenter) {
        self.family = family
        self.levelPresenter = levelPresenter
        self._isOn = AppStorage(wrappedValue: family.enabledByDefault, WarningPreferences.familyKey(family))
    }

    var body: some View {
        Section {
            Toggle("Notify", isOn: $isOn)
            if self.isOn == true {
                switch self.family {
                    case .level:
                        ForEach(self.levelPresenter.readings) { reading in
                            LabeledContent(reading.sensor.name, value: Self.summary(WarningEvaluator.marks(of: reading.sensor)))
                        }
                        Text("Each gauge against its own official marks: a warning at the first flood stage or the mean high water, critical at the second stage, the highest navigable level or the record high. Gauges without marks raise nothing.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    case .hazards:
                        HazardSeverityRows()
                    default:
                        ForEach(WarningRule.rules(for: self.family)) { rule in
                            WarningRuleRows(rule: rule)
                        }
                }
            }
        } header: {
            Label(self.family.label, systemImage: self.family.icon)
        }
    }

    static func summary(_ marks: LevelMarks?) -> String {
        guard let marks else { return "No marks" }
        var text = String(format: "Warning %.2f m (%@)", marks.warning.value, WarningEvaluator.markLabel(marks.warning.name))
        if let critical = marks.critical {
            text += String(format: ", critical %.2f m (%@)", critical.value, WarningEvaluator.markLabel(critical.name))
        }
        return text
    }
}

private struct WarningRuleRows: View {
    let rule: WarningRule
    @AppStorage private var warning: Double
    @AppStorage private var critical: Double

    init(rule: WarningRule) {
        self.rule = rule
        self._warning = AppStorage(wrappedValue: rule.defaultWarning, WarningPreferences.warningKey(rule))
        self._critical = AppStorage(wrappedValue: rule.defaultCritical, WarningPreferences.criticalKey(rule))
    }

    var body: some View {
        LabeledContent(self.rule.label) {
            HStack {
                self.field("Warning", value: $warning)
                self.field("Critical", value: $critical)
                Text(self.rule.symbol)
                    .foregroundColor(.gray)
                    .frame(width: 60, alignment: .leading)
            }
        }
        .help("\(self.rule.direction == .above ? "At or above" : "At or below") the limit. \(self.rule.basis)")
    }

    private func field(_ label: String, value: Binding<Double>) -> some View {
        TextField(label, value: value, format: .number.precision(.fractionLength(0 ... self.rule.fractionDigits)))
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
            .help(label)
    }
}

private struct HazardSeverityRows: View {
    @AppStorage(WarningPreferences.hazardWarningKey) private var warning: Int = WarningPreferences.hazardWarningDefault.rawValue
    @AppStorage(WarningPreferences.hazardCriticalKey) private var critical: Int = WarningPreferences.hazardCriticalDefault.rawValue

    private let severities: [Hazard.Severity] = [.minor, .moderate, .severe, .extreme]

    var body: some View {
        Picker("Warning From", selection: $warning) {
            ForEach(self.severities, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
        }
        Picker("Critical From", selection: $critical) {
            ForEach(self.severities, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
        }
    }
}
