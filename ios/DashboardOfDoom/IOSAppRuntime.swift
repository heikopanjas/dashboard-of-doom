import SwiftUI

@MainActor
final class IOSAppRuntime {
    let weather = WeatherPresenter()
    let forecast = ForecastPresenter()
    let covid = CovidPresenter()
    let levels = LevelPresenter()
    let radiation = RadiationPresenter()
    let hazards = HazardPresenter()
    let particles = ParticlePresenter()
    let surveys = SurveyPresenter()
    let energy = EnergyPresenter()
    let colors = ColorPresenter()
    let pointsOfInterest = PointOfInterestPresenter(fetch: { category, location in
        #if DEBUG
        if IOSPreviewData.isEnabled == true { return IOSPreviewData.points(category: category) }
        #endif
        return try await PointOfInterestController().fetch(category: category, location: location)
    }, fetchesWhenHidden: true)

    lazy var lifecycle = AppActivityLifecycle(
        start: { [weak self] in
            self?.pointsOfInterest.start(updates: AppLocation.shared.updates())
            #if DEBUG
            if IOSPreviewData.isEnabled == true {
                if let self { IOSPreviewData.populate(self) }
                return
            }
            #endif
            AppProcess.shared.start()
        },
        refresh: { AppProcess.shared.refreshSubscriptions() })
}
