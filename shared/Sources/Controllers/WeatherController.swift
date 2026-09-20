import DoomKitProcess
import DoomKitLocation
import CoreLocation
import Foundation
import WeatherKit

class WeatherController: ProcessController {
    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        var data: [ProcessSensor] = []
        var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]

        let weather = try await WeatherService.shared.weather(for: CLLocation(latitude: location.latitude, longitude: location.longitude))
        let current = weather.currentWeather

        let temperature = Measurement<Dimension>(value: current.temperature.value, unit: current.temperature.unit)
        measurements[.weather(.temperature)] = [ProcessValue(value: temperature, quality: .good)]

        let apparentTemperature = Measurement<Dimension>(value: current.apparentTemperature.value, unit: current.apparentTemperature.unit)
        measurements[.weather(.apparentTemperature)] = [ProcessValue(value: apparentTemperature, quality: .good)]

        let dewPoint = Measurement<Dimension>(value: current.dewPoint.value, unit: current.dewPoint.unit)
        measurements[.weather(.dewPoint)] = [ProcessValue(value: dewPoint, quality: .good)]

        let humidity = Measurement<Dimension>(value: current.humidity * 100, unit: UnitPercentage.percent)
        measurements[.weather(.humidity)] = [ProcessValue(value: humidity, quality: .good)]

        let precipitationIntensity = Measurement<Dimension>(value: current.precipitationIntensity.value, unit: current.precipitationIntensity.unit)
        measurements[.weather(.precipitationIntensity)] = [ProcessValue(value: precipitationIntensity, quality: .good)]

        let pressure = Measurement<Dimension>(value: current.pressure.value, unit: current.pressure.unit)
        measurements[.weather(.pressure)] = [ProcessValue(value: pressure, quality: .good)]

        let visibility = Measurement<Dimension>(value: current.visibility.value, unit: current.visibility.unit)
        measurements[.weather(.visibility)] = [ProcessValue(value: visibility, quality: .good)]

        let cloudCover = Measurement<Dimension>(value: current.cloudCover * 100, unit: UnitPercentage.percent)
        measurements[.weather(.cloudCover)] = [ProcessValue<Dimension>(value: cloudCover, quality: .good)]

        let cloudCoverLow = Measurement<Dimension>(value: current.cloudCoverByAltitude.low * 100, unit: UnitPercentage.percent)
        measurements[.weather(.cloudCoverLow)] = [ProcessValue(value: cloudCoverLow, quality: .good)]

        let cloudCoverMedium = Measurement<Dimension>(value: current.cloudCoverByAltitude.medium * 100, unit: UnitPercentage.percent)
        measurements[.weather(.cloudCoverMedium)] = [ProcessValue(value: cloudCoverMedium, quality: .good)]

        let cloudCoverHigh = Measurement<Dimension>(value: current.cloudCoverByAltitude.high * 100, unit: UnitPercentage.percent)
        measurements[.weather(.cloudCoverHigh)] = [ProcessValue(value: cloudCoverHigh, quality: .good)]

        let windSpeed = Measurement<Dimension>(value: current.wind.speed.value, unit: current.wind.speed.unit)
        measurements[.weather(.windSpeed)] = [ProcessValue(value: windSpeed, quality: .good)]

        if let gust = current.wind.gust {
            let windGust = Measurement<Dimension>(value: gust.value, unit: gust.unit)
            measurements[.weather(.windGust)] = [ProcessValue(value: windGust, quality: .good)]
        }

        if let placemark = await GeocodingService.reverseGeocodeLocation(latitude: location.latitude, longitude: location.longitude) {
            let sensor = ProcessSensor(name: "", location: location, placemark: placemark, customData: ["icon": current.symbolName], measurements: measurements, timestamp: Date.now)
            data.append(sensor)
        }
        return data
    }
}
