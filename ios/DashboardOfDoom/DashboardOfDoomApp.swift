import SwiftUI

@main
struct DashboardOfDoomApp: App {
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) private var delegate
    @AppStorage("enableDarkTheme") private var enableDarkTheme = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(self.enableDarkTheme == true ? .dark : nil)
                .environment(self.delegate.runtime.weather)
                .environment(self.delegate.runtime.forecast)
                .environment(self.delegate.runtime.covid)
                .environment(self.delegate.runtime.levels)
                .environment(self.delegate.runtime.radiation)
                .environment(self.delegate.runtime.hazards)
                .environment(self.delegate.runtime.particles)
                .environment(self.delegate.runtime.surveys)
                .environment(self.delegate.runtime.colors)
                .environment(self.delegate.runtime.pointsOfInterest)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    self.delegate.runtime.lifecycle.enteredBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    self.delegate.runtime.lifecycle.becameActive()
                }
        }
    }
}
