import DoomKitLocation
import DoomKitServices
import Foundation
import Testing

@Suite struct DataSourcesTests {
    @Test func everySourceHasATopicAndACreditAndNoTopicTwice() {
        let sources = DataSources.all(year: 2026)
        #expect(Set(sources.map { $0.topic }).count == sources.count)
        for source in sources {
            #expect(source.attribution.isEmpty == false, "\(source.topic)")
            // A required credit names its licence, and a named licence links to it, except where there is no licence text to link.
            if source.isRequired == true {
                #expect(source.licence != nil, "\(source.topic)")
                #expect(source.licenceURL != nil, "\(source.topic)")
            }
        }
    }

    @Test func theWordingIsTheProvidersOwnWhereTheyPrescribeIt() throws {
        let sources = Dictionary(uniqueKeysWithValues: DataSources.all(year: 2031).map { ($0.topic, $0) })
        // BKG: the year of the last retrieval, the licence and the list of data sources.
        let bkg = try #require(sources["District Boundaries"])
        #expect(bkg.attribution.hasPrefix("© BKG (2031) dl-de/by-2-0, Datenquellen: https://sgx.geodatenzentrum.de/") == true)
        #expect(bkg.sourceURL?.absoluteString == "https://www.bkg.bund.de")
        #expect(sources["Election Polls"]?.attribution == "Daten von dawum.de (Open Database License (ODbL)).")
        #expect(sources["Radiation"]?.attribution.hasPrefix(DataSources.radiationNote) == true)
        #expect(sources["Places"]?.licenceURL?.absoluteString == "https://www.openstreetmap.org/copyright")
        #expect(sources["Fuel Prices"]?.attribution.contains("tankerkoenig.de") == true)
    }

    @Test func everyWarningNamesWhoIssuedItAndDWDInItsOwnWords() {
        func hazard(_ feed: HazardFeed) -> Hazard {
            return Hazard(
                id: feed.rawValue, feed: feed, event: nil, headline: "", description: "", instruction: nil, severity: .moderate, sent: .now,
                expires: nil, areaDescription: nil, location: Location(latitude: 52.5, longitude: 13.4), distance: 0, placemark: nil)
        }
        #expect(hazard(.dwd).sourceNote == "Quelle: Deutscher Wetterdienst")
        for feed in HazardFeed.allCases {
            #expect(hazard(feed).sourceNote.hasPrefix("Quelle: ") == true)
        }
    }
}
