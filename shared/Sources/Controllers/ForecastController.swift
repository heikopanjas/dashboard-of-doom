import DoomKitProcess
import DoomKitLocation
import CoreLocation
import Foundation
import WeatherKit

class ForecastController: ProcessController {
    func refreshData(for location: Location) async throws -> [ProcessSensor] {
        var data: [ProcessSensor] = []

        if let placemark = await GeocodingService.reverseGeocodeLocation(location: location) {
            var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]

            let weather = try await WeatherService.shared.weather(for: CLLocation(latitude: location.latitude, longitude: location.longitude))
            let forecast = weather.hourlyForecast.forecast.prefix(111)

            let cloudCover = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.cloudCover * 100, unit: UnitPercentage.percent), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.cloudCover)] = cloudCover

            let dewPoint = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.dewPoint.value, unit: $0.dewPoint.unit), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.dewPoint)] = dewPoint

            let humidity = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.humidity * 100, unit: UnitPercentage.percent), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.humidity)] = humidity

            let precipitationChance = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.precipitationChance * 100, unit: UnitPercentage.percent), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.precipitationChance)] = precipitationChance

            let precipitationAmount = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.precipitationAmount.value, unit: $0.precipitationAmount.unit), quality: .uncertain,
                    timestamp: $0.date
                )
            }
            measurements[.forecast(.precipitationAmount)] = precipitationAmount

            let snowfallAmount = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.snowfallAmount.value, unit: $0.snowfallAmount.unit), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.snowfallAmount)] = snowfallAmount

            let pressure = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.pressure.value, unit: $0.pressure.unit), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.pressure)] = pressure

            let temperature = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.temperature.value, unit: $0.temperature.unit),
                    customData: ["icon": $0.symbolName], quality: .uncertain,
                    timestamp: $0.date
                )
            }
            measurements[.forecast(.temperature)] = temperature

            let apparentTemperature = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.apparentTemperature.value, unit: $0.temperature.unit), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.apparentTemperature)] = apparentTemperature

            let visibility = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.visibility.value, unit: $0.visibility.unit), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.visibility)] = visibility

//            let windDirection = forecast.map {
//                ProcessValue<Dimension>(
//                    value: Measurement(value: $0.wind.direction.value, unit: $0.wind.direction.unit), quality: .uncertain, timestamp: $0.date)
//            }
//            measurements[.forecast(.windDirection)] = windDirection

            let windSpeed = forecast.map {
                ProcessValue<Dimension>(
                    value: Measurement(value: $0.wind.speed.value, unit: $0.wind.speed.unit), quality: .uncertain, timestamp: $0.date)
            }
            measurements[.forecast(.windSpeed)] = windSpeed

            let windGust = forecast.map {
                if let gust = $0.wind.gust {
                    ProcessValue<Dimension>(value: Measurement(value: gust.value, unit: gust.unit), quality: .uncertain, timestamp: $0.date)
                }
                else {
                    ProcessValue<Dimension>(value: Measurement(value: 0, unit: UnitSpeed.baseUnit()), quality: .unknown, timestamp: $0.date)
                }

            }
            measurements[.forecast(.windGust)] = windGust

            let sensor = ProcessSensor(
                name: "Forecast", location: location, placemark: placemark, measurements: self.sanitizeData(measurements: measurements),
                timestamp: Date.now)
            data.append(sensor)
        }

        return data
    }

    private func sanitizeData(measurements: [ProcessSelector: [ProcessValue<Dimension>]]) -> [ProcessSelector: [ProcessValue<Dimension>]] {
        var sanitizedMeasurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
        for (selector, forecast) in measurements {
            var sanitizedForecast: [ProcessValue<Dimension>] = []
            for value in forecast {
                let quality = (value.timestamp <= Date.now) ? ProcessQuality.good : ProcessQuality.uncertain
                sanitizedForecast.append(
                    ProcessValue<Dimension>(
                        value: Measurement(value: value.value.value, unit: value.value.unit),
                        customData: value.customData,
                        quality: quality,
                        timestamp: value.timestamp
                    )
                )
            }
            sanitizedMeasurements[selector] = sanitizedForecast
        }
        return sanitizedMeasurements
    }
}
