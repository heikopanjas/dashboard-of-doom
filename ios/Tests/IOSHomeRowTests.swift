import DoomKitLocation
import DoomKitProcess
import Foundation
import Testing

@MainActor
struct IOSHomeRowTests {
    private static let start = Date(timeIntervalSince1970: 1_800_000_000)

    private static func value(_ number: Double, unit: Dimension, hours: Int, icon: String? = nil) -> ProcessValue<Dimension> {
        let timestamp = Self.start.addingTimeInterval(Double(hours) * 3600)
        if let icon {
            return ProcessValue(value: Measurement(value: number, unit: unit), customData: ["icon": icon], quality: .uncertain, timestamp: timestamp)
        }
        return ProcessValue(value: Measurement(value: number, unit: unit), quality: .uncertain, timestamp: timestamp)
    }

    @Test func forecastHoursPairByTimestampAndKeepMissingChance() {
        let temperature = (-2..<30).map { Self.value(Double($0), unit: UnitTemperature.celsius, hours: $0, icon: "sun.max") }
        // No chance for hour 3, and the hours arrive out of order.
        let chance = (0..<30).filter { $0 != 3 }.reversed().map { Self.value(Double($0 * 3), unit: UnitPercentage.percent, hours: $0) }
        let hours = ForecastStripView.hours(temperature: temperature.shuffled(), precipitation: chance, from: Self.start)
        #expect(hours.count == ForecastStripView.hourLimit)
        #expect(hours.first?.timestamp == Self.start)
        #expect(hours.map(\.timestamp) == hours.map(\.timestamp).sorted())
        #expect(hours[1].precipitationChance == 3)
        #expect(hours[3].precipitationChance == nil)
        #expect(hours[0].icon == "sun.max")
    }

    @Test func conditionsItemsFollowAvailableSeriesAndConvertUnits() {
        var current: [ProcessSelector: ProcessValue<Dimension>] = [
            .weather(.apparentTemperature): Self.value(20.44, unit: UnitTemperature.celsius, hours: 0),
            .weather(.windSpeed): Self.value(10, unit: UnitSpeed.metersPerSecond, hours: 0),
            .weather(.pressure): Self.value(1013, unit: UnitPressure.millibars, hours: 0),
        ]
        var items = CurrentConditionsView.items(current: current)
        #expect(items.map(\.title) == ["Feels like", "Wind", "Pressure"])
        #expect(items[0].value == "20.4°C")
        #expect(items[1].value == "36 km/h")
        #expect(items[2].value == "1013 hPa")

        current[.weather(.windGust)] = Self.value(15, unit: UnitSpeed.metersPerSecond, hours: 0)
        current[.weather(.humidity)] = Self.value(64, unit: UnitPercentage.percent, hours: 0)
        items = CurrentConditionsView.items(current: current)
        #expect(items.map(\.title) == ["Feels like", "Humidity", "Wind", "Pressure"])
        #expect(items[1].value == "64%")
        #expect(items[2].value == "36, gusts 54 km/h")
    }

    @Test func nearestPlacesPicksClosestPerCategoryAndSkipsEmptyOnes() {
        let here = Location(latitude: 52.51889, longitude: 13.36528)
        func point(_ id: Int64, _ category: PointOfInterestCategory, _ latitudeOffset: Double) -> PointOfInterest {
            return PointOfInterest(
                category: category, elementType: "node", elementID: id, name: "P\(id)",
                location: Location(latitude: here.latitude + latitudeOffset, longitude: here.longitude))
        }
        let points = [
            point(1, .pharmacies, 0.010), point(2, .pharmacies, 0.002), point(3, .hospitals, 0.005),
            point(4, .stores, 0.001), point(5, .cemeteries, 0.001),
        ]
        let nearest = NearestPlacesView.nearest(points: points, from: here)
        #expect(nearest.map(\.point.elementID) == [2, 3, 4, 5])
        #expect(nearest.map(\.category) == [.pharmacies, .hospitals, .stores, .cemeteries])
        #expect(nearest[0].distance < nearest[1].distance)
        #expect(NearestPlacesView.nearest(points: [], from: here).isEmpty)
    }

    @Test func distanceStringSwitchesToKilometresAtOneThousand() {
        #expect(NearestPlacesView.distanceString(999) == "999 m")
        #expect(NearestPlacesView.distanceString(1000) == "1.0 km")
        #expect(NearestPlacesView.distanceString(1234) == "1.2 km")
    }
}
