import DoomKitProcess
import SwiftUI
import Testing

@Suite struct ColorSensorTests {
    /// The color of each of the six labels on the home map.
    private static let homeLabelColors: [Color] = [
        .weather(.temperature), .covid(.incidence), .particle(.pm10), .water(.level), .radiation(.total), .survey(.fascists)
    ].map { Color.faceplate(selector: $0) }

    @Test func theNearestSensorsKeepTheirHomeColors() {
        #expect(Color.sensor(selector: .radiation(.total), index: 0) == Color.faceplate(selector: .radiation(.total)))
        #expect(Color.sensor(selector: .water(.level), index: 0) == Color.faceplate(selector: .water(.level)))
    }

    @Test func thePaletteIsTheSixHomeLabelColorsAndNoTwoAreAlike() {
        let palette = Color.radiationSensors + Color.waterSensors
        #expect(palette.count == 6)
        #expect(Set(palette).count == 6)
        #expect(Set(palette) == Set(Self.homeLabelColors))
    }

    @Test func theExtrasFollowTheOrderOfTheTab() {
        #expect([0, 1, 2].map { Color.sensor(selector: .radiation(.total), index: $0) } == [Color.radiation, Color.survey, Color.covid])
        #expect([0, 1, 2].map { Color.sensor(selector: .water(.level), index: $0) } == [Color.water, Color.particle, Color.weather])
    }

    @Test func theParticleStationsStartWithTheHomeParticleColorAndAreAllDifferent() {
        #expect(Color.particleSensors.count == 3)
        #expect(Set(Color.particleSensors).count == 3)
        #expect(Set(Color.particleSensors).isSubset(of: Set(Self.homeLabelColors)) == true)
        #expect(Color.sensor(selector: .particle(.pm10), index: 0) == Color.faceplate(selector: .particle(.pm10)))
        // Every pollutant of a station has the same color: the color belongs to the station.
        #expect(Color.sensor(selector: .particle(.no2), index: 1) == Color.sensor(selector: .particle(.pm10), index: 1))
        #expect(Color.sensor(selector: .particle(.pm10), index: 3) == Color.sensor(selector: .particle(.pm10), index: 0))
    }

    @Test func theFuelStationsUseAllSixHomeColoursOnce() {
        #expect(Color.fuelStations.count == 6)
        #expect(Set(Color.fuelStations).count == 6)
        #expect(Set(Color.fuelStations) == Set(Self.homeLabelColors))
    }

    @Test func aSourceWithoutAListKeepsItsCategoryColor() {
        for selector in [ProcessSelector.weather(.temperature), .forecast(.temperature), .covid(.incidence), .survey(.fascists)] {
            #expect(Color.sensor(selector: selector, index: 2) == Color.faceplate(selector: selector))
        }
    }

    @Test func anIndexPastTheEndWrapsInsteadOfFailing() {
        #expect(Color.sensor(selector: .radiation(.total), index: 3) == Color.sensor(selector: .radiation(.total), index: 0))
        #expect(Color.sensor(selector: .water(.level), index: 7) == Color.sensor(selector: .water(.level), index: 1))
        #expect(Color.sensor(selector: .water(.level), index: -1) == Color.sensor(selector: .water(.level), index: 2))
    }
}
