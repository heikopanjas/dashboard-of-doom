import DoomKitLocation
import Foundation
import SwiftUI
import Testing

@Suite struct FuelMapViewTests {
    private func station(
        _ id: String, e5: Double? = nil, diesel: Double? = nil, open: Bool = true, distance: Double = 1, name: String = "Station"
    ) -> FuelStation {
        var prices: [FuelStation.Fuel: Double] = [:]
        if let e5 = e5 { prices[.e5] = e5 }
        if let diesel = diesel { prices[.diesel] = diesel }
        return FuelStation(
            id: id, name: name, brand: nil, street: nil, houseNumber: nil, location: Location(latitude: 52.5, longitude: 13.4),
            distance: distance, isOpen: open, prices: prices)
    }

    @Test func theCheapestOrderIsTheDearestReversed() {
        let stations = (1 ... 10).map { self.station("s\($0)", e5: 2.0 + Double($0) / 100) }
        let cheapest = FuelMapView.ranked(stations: stations, fuel: .e5, order: .cheapest)
        #expect(cheapest.map { $0.id } == ["s1", "s2", "s3", "s4", "s5", "s6"])
        // Closed stations stay out whichever end is asked for.
        let shut = [self.station("shut", e5: 0.99, open: false), self.station("open", e5: 1.50)]
        #expect(FuelMapView.ranked(stations: shut, fuel: .e5, order: .cheapest).map { $0.id } == ["open"])
    }

    @Test func equalPricesStillPutTheNearerFirstWhenCheapest() {
        let stations = [self.station("far", e5: 2.0, distance: 8), self.station("near", e5: 2.0, distance: 2)]
        #expect(FuelMapView.ranked(stations: stations, fuel: .e5, order: .cheapest).map { $0.id } == ["near", "far"])
    }

    @Test func theDearestComeFirstAndOnlySix() {
        let stations = (1 ... 10).map { self.station("s\($0)", e5: 2.0 + Double($0) / 100) }
        let ranked = FuelMapView.ranked(stations: stations, fuel: .e5)
        // Six is the label placement solver's limit, so that is what the map asks for.
        #expect(ranked.count == 6)
        #expect(ranked.map { $0.id } == ["s10", "s9", "s8", "s7", "s6", "s5"])
    }

    @Test func aClosedStationIsNotListedHoweverDearItIs() {
        let stations = [self.station("shut", e5: 9.99, open: false), self.station("open", e5: 1.50)]
        #expect(FuelMapView.ranked(stations: stations, fuel: .e5).map { $0.id } == ["open"])
    }

    @Test func aStationThatDoesNotSellTheFuelIsNotListed() {
        let stations = [self.station("petrol", e5: 2.0), self.station("dieselOnly", diesel: 2.5)]
        #expect(FuelMapView.ranked(stations: stations, fuel: .e5).map { $0.id } == ["petrol"])
        #expect(FuelMapView.ranked(stations: stations, fuel: .diesel).map { $0.id } == ["dieselOnly"])
        #expect(FuelMapView.ranked(stations: stations, fuel: .e10).isEmpty == true)
    }

    @Test func theFuelDecidesTheOrder() {
        let stations = [self.station("a", e5: 2.10, diesel: 2.50), self.station("b", e5: 2.20, diesel: 2.40)]
        #expect(FuelMapView.ranked(stations: stations, fuel: .e5).map { $0.id } == ["b", "a"])
        #expect(FuelMapView.ranked(stations: stations, fuel: .diesel).map { $0.id } == ["a", "b"])
    }

    @Test func equallyDearStationsAreOrderedByDistanceSoTheListDoesNotWobble() {
        let stations = [self.station("far", e5: 2.0, distance: 8), self.station("near", e5: 2.0, distance: 2)]
        #expect(FuelMapView.ranked(stations: stations, fuel: .e5).map { $0.id } == ["near", "far"])
    }

    @Test func fewerStationsThanTheLimitAndNoneAtAll() {
        #expect(FuelMapView.ranked(stations: [], fuel: .e5).isEmpty == true)
        let two = [self.station("a", e5: 2.0), self.station("b", e5: 2.1)]
        #expect(FuelMapView.ranked(stations: two, fuel: .e5).count == 2)
        #expect(FuelMapView.ranked(stations: two, fuel: .e5, limit: 0).isEmpty == true)
    }

    @Test func pricesAreWrittenTheWayAGermanPumpBoardWritesThem() {
        // A comma, and the tenth of a cent raised and small.
        #expect(FuelMapView.priceString(2.409) == "2,40\u{2079} €")
        #expect(FuelMapView.priceString(2.319) == "2,31\u{2079} €")
        #expect(FuelMapView.priceString(2.0) == "2,00\u{2070} €")
        #expect(FuelMapView.priceString(1.999) == "1,99\u{2079} €")
        #expect(FuelMapView.priceString(10.5) == "10,50\u{2070} €")
        #expect(FuelMapView.priceString(nil) == "n/a")
        // A price that never came off a pump does not crash the formatter.
        #expect(FuelMapView.parts(of: -1) == nil)
        #expect(FuelMapView.parts(of: Double.nan) == nil)
        #expect(FuelMapView.priceString(Double.infinity) == "n/a")
    }

    @Test func everyStationBecomesAPinWithItsRankAsTheIconAndItsPriceAsTheLabel() {
        let stations = (1 ... 8).map { self.station("s\($0)", e5: 2.0 + Double($0) / 100) }
        let pins = FuelMapView.annotations(stations: stations, fuel: .e5)
        // Six, the placement solver's limit, dearest first.
        #expect(pins.count == 6)
        #expect(pins.map { $0.id } == ["fuel-s8", "fuel-s7", "fuel-s6", "fuel-s5", "fuel-s4", "fuel-s3"])
        #expect(pins.map { $0.icon } == ["1.circle.fill", "2.circle.fill", "3.circle.fill", "4.circle.fill", "5.circle.fill", "6.circle.fill"])
        #expect(pins.first?.faceplate == "2,08\u{2070} €")
        // One of the six home label colours each, warm first, and no two alike.
        #expect(pins.map { $0.displayColor } == [Color.radiation, Color.survey, Color.water, Color.particle, Color.weather, Color.covid])
        #expect(Set(pins.map { $0.displayColor }).count == 6)
        #expect(pins.allSatisfy { $0.showsLabel == true } == true)
        // A rank the symbol set does not reach falls back rather than asking for a symbol that does not exist.
        #expect(FuelMapView.rankIcon(9) == "fuelpump.fill")
    }

    @Test func theOrderPickerChangesWhichStationsArePinned() {
        let stations = (1 ... 8).map { self.station("s\($0)", e5: 2.0 + Double($0) / 100) }
        let cheapest = FuelMapView.annotations(stations: stations, fuel: .e5, order: .cheapest)
        #expect(cheapest.map { $0.id } == ["fuel-s1", "fuel-s2", "fuel-s3", "fuel-s4", "fuel-s5", "fuel-s6"])
        #expect(FuelMapView.annotations(stations: [], fuel: .e5).isEmpty == true)
    }
}
