import DoomKitProcess
import SwiftUI
import UserNotifications

/// The Notifications section of Settings: the master switch, what iOS allows, and a row per family that opens its limits.
struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(WarningPreferences.enabledKey) private var enabled: Bool = false
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                Toggle("Notify", isOn: $enabled)
                    .onChange(of: enabled) { _, isOn in
                        BackgroundRefresh.schedule()
                        guard isOn == true else { return }
                        Task {
                            _ = await NotificationCenterPoster.shared.requestAuthorization()
                            self.status = await NotificationCenterPoster.shared.authorizationStatus()
                        }
                    }
                HStack {
                    Text("Sends a notice when a reading reaches its warning or its critical limit, once for each, and checks now and then in the background. Nothing is sent about the Berlin fallback location.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                if self.enabled == true && self.status == .denied {
                    HStack {
                        Text("Notifications are off for this app in iOS Settings, so nothing can appear.")
                            .font(.footnote)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { self.openURL(url) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if self.enabled == true {
                    ForEach(WarningFamily.allCases, id: \.self) { family in
                        Divider()
                        NavigationLink {
                            NotificationFamilySettingsView(family: family)
                        } label: {
                            NotificationFamilyRow(family: family)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .task(id: self.scenePhase) {
            // Coming back from iOS Settings is a scene phase change, so a permission granted there shows up at once.
            self.status = await NotificationCenterPoster.shared.authorizationStatus()
        }
    }
}

private struct NotificationFamilyRow: View {
    let family: WarningFamily
    @AppStorage private var isOn: Bool

    init(family: WarningFamily) {
        self.family = family
        self._isOn = AppStorage(wrappedValue: family.enabledByDefault, WarningPreferences.familyKey(family))
    }

    var body: some View {
        HStack {
            Image(systemName: self.family.icon)
                .frame(width: 24)
                .accentLabel()
            Text(self.family.label)
            Spacer()
            Text(self.isOn == true ? "On" : "Off")
                .foregroundColor(.gray)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
    }
}

/// One family's switch and limits.
struct NotificationFamilySettingsView: View {
    let family: WarningFamily
    @AppStorage private var isOn: Bool

    init(family: WarningFamily) {
        self.family = family
        self._isOn = AppStorage(wrappedValue: family.enabledByDefault, WarningPreferences.familyKey(family))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    Toggle("Notify", isOn: $isOn)
                    HStack {
                        Text(self.explainer)
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                switch self.family {
                    case .level:
                        LevelMarksCard()
                    case .hazards:
                        HazardSeverityCard()
                    default:
                        ForEach(WarningRule.rules(for: self.family)) { rule in
                            WarningRuleCard(rule: rule)
                        }
                }
            }
            .padding()
        }
        .navigationTitle(self.family.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var explainer: String {
        switch self.family {
            case .weather:
                return "Current weather and the forecast for the next 24 hours, so a notice can come before the weather does."
            case .hazards:
                return "Official NINA warnings that cover your location or lie nearby, once for each new warning. Needs Warnings on under Home."
            case .level:
                return "Every gauge that is loaded, against its own official marks. Needs Water on under Home."
            case .radiation:
                return "Every radiation station that is loaded. Needs Radiation on under Home."
            case .particles:
                return "Every air quality station that is loaded, one notice per pollutant. Needs Particulate Matter on under Home."
            case .covid:
                return "The reporting district's incidence. Needs COVID-19 on."
            case .energy:
                return "The daily crude oil and LNG prices. Needs Energy on."
            case .fuel:
                return "Needs Energy on and a Tankerkoenig key."
        }
    }
}

/// A rule's two limits, stored under the rule's own keys.
private struct WarningRuleCard: View {
    let rule: WarningRule
    @AppStorage private var warning: Double
    @AppStorage private var critical: Double

    init(rule: WarningRule) {
        self.rule = rule
        self._warning = AppStorage(wrappedValue: rule.defaultWarning, WarningPreferences.warningKey(rule))
        self._critical = AppStorage(wrappedValue: rule.defaultCritical, WarningPreferences.criticalKey(rule))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(self.rule.label)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(spacing: 12) {
                self.row("Warning", value: $warning)
                self.row("Critical", value: $critical)
                HStack {
                    Text("\(self.rule.direction == .above ? "At or above" : "At or below") the limit. \(self.rule.basis)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
                if self.isOutOfOrder == true {
                    HStack {
                        Text("The critical limit is on the wrong side of the warning limit, so the warning limit counts for both.")
                            .font(.footnote)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                Button("Restore Defaults") {
                    self.warning = self.rule.defaultWarning
                    self.critical = self.rule.defaultCritical
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    private var isOutOfOrder: Bool {
        return self.rule.direction == .above ? self.critical < self.warning : self.critical > self.warning
    }

    private func row(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number.precision(.fractionLength(0 ... self.rule.fractionDigits)))
                .keyboardType(self.rule.range.lowerBound < 0 ? .numbersAndPunctuation : .decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .textFieldStyle(.roundedBorder)
            Text(self.rule.symbol)
                .foregroundColor(.gray)
                .frame(minWidth: 56, alignment: .leading)
        }
    }
}

private struct HazardSeverityCard: View {
    @AppStorage(WarningPreferences.hazardWarningKey) private var warning: Int = WarningPreferences.hazardWarningDefault.rawValue
    @AppStorage(WarningPreferences.hazardCriticalKey) private var critical: Int = WarningPreferences.hazardCriticalDefault.rawValue

    private let severities: [Hazard.Severity] = [.minor, .moderate, .severe, .extreme]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Severity")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 12) {
                Text("Warning from")
                self.picker($warning)
                Text("Critical from")
                self.picker($critical)
                HStack {
                    Text("The severity the issuing office gives a warning. The DWD's yellow, orange, red and purple are minor, moderate, severe and extreme.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    private func picker(_ selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(self.severities, id: \.rawValue) { severity in
                Text(severity.label).tag(severity.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Level has no numbers to set: each gauge has its own marks, so this shows the ones of the gauges that are loaded.
private struct LevelMarksCard: View {
    @Environment(LevelPresenter.self) private var presenter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Marks")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 12) {
                if self.presenter.readings.isEmpty == true {
                    Text("No gauge is loaded yet.")
                        .foregroundColor(.gray)
                }
                ForEach(self.presenter.readings) { reading in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SensorHeaderView.displayName(reading.sensor.name))
                        Text(Self.summary(WarningEvaluator.marks(of: reading.sensor)))
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                HStack {
                    Text("A warning at the first official flood stage, or the mean high water where there is none. Critical at the second stage, the highest navigable level or the record high, whichever comes first above it. About a quarter of all gauges, many on canals, publish no marks and raise no notices.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    static func summary(_ marks: LevelMarks?) -> String {
        guard let marks else { return "This gauge publishes no marks." }
        var text = String(format: "Warning at %.2f m (%@)", marks.warning.value, WarningEvaluator.markLabel(marks.warning.name))
        if let critical = marks.critical {
            text += String(format: ", critical at %.2f m (%@)", critical.value, WarningEvaluator.markLabel(critical.name))
        }
        return text + "."
    }
}
