import DoomKitLocation
import DoomKitServices
import Foundation
import Testing

/// Parsing only. Nothing here touches the network.
struct HazardControllerTests {
    private static let now = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00+02:00")!
    private static let hkw = Location(latitude: 52.51889, longitude: 13.36528)

    private static func data(_ json: String) -> Data {
        return Data(json.utf8)
    }

    @Test func listDropsCancellationsAndExpiredEntries() throws {
        let list = Self.data(
            """
            [
              {"id": "a", "type": "Alert", "severity": "Moderate", "expiresDate": "2026-09-20T20:00:00+02:00"},
              {"id": "b", "type": "Cancel", "severity": "Moderate"},
              {"id": "c", "type": "Alert", "severity": "Minor", "expiresDate": "2026-09-19T20:00:00+02:00"},
              {"id": "d", "type": "Alert", "severity": "Minor"}
            ]
            """)
        let candidates = try HazardController.parseList(list, feed: .dwd, now: Self.now)
        #expect(candidates.map(\.id) == ["a", "d"])
        #expect(candidates[0].expires != nil)
        #expect(candidates[1].expires == nil)
    }

    @Test func detailsPreferGermanOverEnglishRegardlessOfOrder() throws {
        let detail = Self.data(
            """
            {
              "identifier": "x", "sent": "2026-09-19T19:01:00+02:00",
              "info": [
                {"language": "en", "headline": "Storm", "description": "English", "severity": "Moderate"},
                {"language": "de-LS", "headline": "Sturm einfach", "description": "Leicht", "severity": "Moderate"},
                {"language": "de-DE", "headline": "Sturm", "description": "Erste Zeile<br/>Zweite Zeile",
                 "instruction": "Fenster schliessen", "event": "STURM", "severity": "Moderate",
                 "expires": "2026-09-20T20:00:00+02:00",
                 "area": [{"areaDesc": "Berlin"}, {"areaDesc": ""}, {"areaDesc": "Potsdam"}]}
              ]
            }
            """)
        let details = try #require(try HazardController.parseDetails(detail, now: Self.now))
        #expect(details.headline == "Sturm")
        #expect(details.description == "Erste Zeile\nZweite Zeile")
        #expect(details.instruction == "Fenster schliessen")
        #expect(details.event == "STURM")
        #expect(details.severity == .moderate)
        #expect(details.areaDescription == "Berlin, Potsdam")
        #expect(details.expires != nil)
    }

    @Test func detailsFallBackToFirstInfoAndDropExpiredOrStale() throws {
        let english = Self.data(
            """
            {"identifier": "x", "sent": "2026-09-19T19:01:00+02:00",
             "info": [{"language": "en", "headline": "Storm", "severity": "Extreme"}]}
            """)
        let details = try #require(try HazardController.parseDetails(english, now: Self.now))
        #expect(details.headline == "Storm")
        #expect(details.severity == .extreme)
        #expect(details.areaDescription == nil)

        let expired = Self.data(
            """
            {"identifier": "x", "sent": "2026-09-19T19:01:00+02:00",
             "info": [{"language": "de", "headline": "Alt", "expires": "2026-09-20T11:00:00+02:00"}]}
            """)
        #expect(try HazardController.parseDetails(expired, now: Self.now) == nil)

        let stale = Self.data(
            """
            {"identifier": "x", "sent": "2026-08-01T12:00:00+02:00",
             "info": [{"language": "de", "headline": "Uralt"}]}
            """)
        #expect(try HazardController.parseDetails(stale, now: Self.now) == nil)
    }

    @Test func featureCollectionYieldsEveryFeatureAndBothGeometryTypes() {
        let json: [String: Any] = [
            "type": "FeatureCollection",
            "features": [
                ["geometry": ["type": "Polygon", "coordinates": [[[13.0, 52.0], [13.1, 52.0], [13.1, 52.1], [13.0, 52.0]]]]],
                ["geometry": ["type": "MultiPolygon", "coordinates": [
                    [[[14.0, 53.0], [14.1, 53.0], [14.1, 53.1], [14.0, 53.0]]],
                    [[[15.0, 54.0], [15.1, 54.0], [15.1, 54.1], [15.0, 54.0]]],
                ]]],
                ["geometry": ["type": "Point", "coordinates": [1.0, 2.0]]],
            ],
        ]
        let polygons = GeoJSON.polygons(fromFeatureCollection: json)
        #expect(polygons.count == 3)
        #expect(polygons[0].first?.latitude == 52.0)
        #expect(polygons[0].first?.longitude == 13.0)
        #expect(polygons[2].first?.latitude == 54.0)
    }

    @Test func sourceURLPointsAtTheAlertPageOnNina() {
        func hazard(_ id: String) -> Hazard {
            return Hazard(
                id: id, feed: .dwd, event: nil, headline: id, description: "", instruction: nil, severity: .minor,
                sent: Self.now, expires: nil, areaDescription: nil, location: Self.hkw, distance: 0, placemark: nil)
        }
        #expect(
            hazard("dwdmap.2.49.0.0.276.0.DWD.PVW.1789822740000.0e032817-18f7-4426-ba05-2d596cd4616b.MUL").sourceURL?.absoluteString
                == "https://warnung.bund.de/meldungen/dwdmap.2.49.0.0.276.0.DWD.PVW.1789822740000.0e032817-18f7-4426-ba05-2d596cd4616b.MUL/warnung/")
        #expect(
            hazard("mow.DE-SL-SLS-W038-20260904-000").sourceURL?.absoluteString
                == "https://warnung.bund.de/meldungen/mow.DE-SL-SLS-W038-20260904-000/warnung/")
        #expect(hazard("odd id").sourceURL?.absoluteString == "https://warnung.bund.de/meldungen/odd%20id/warnung/")
    }

    @Test func placementKeepsInsideAndNearbyAndDropsFarAlerts() {
        let around = [
            Location(latitude: 52.4, longitude: 13.2), Location(latitude: 52.4, longitude: 13.5),
            Location(latitude: 52.6, longitude: 13.5), Location(latitude: 52.6, longitude: 13.2),
        ]
        let candidate = HazardController.Candidate(id: "in", feed: .dwd, expires: nil)
        let inside = HazardController.place(candidate, polygons: [around], near: Self.hkw)
        #expect(inside?.distance == 0)

        // Roughly 30 km east of HKW: inside the 50 km weather radius, outside the 25 km civil one.
        let east = [
            Location(latitude: 52.4, longitude: 13.8), Location(latitude: 52.4, longitude: 14.0),
            Location(latitude: 52.6, longitude: 14.0), Location(latitude: 52.6, longitude: 13.8),
        ]
        let weather = HazardController.place(HazardController.Candidate(id: "w", feed: .dwd, expires: nil), polygons: [east], near: Self.hkw)
        let civil = HazardController.place(HazardController.Candidate(id: "c", feed: .mowas, expires: nil), polygons: [east], near: Self.hkw)
        #expect(weather != nil)
        #expect((weather?.distance ?? 0) > 25_000)
        #expect(civil == nil)
    }
}
