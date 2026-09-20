import DoomKitLocation
import DoomKitNetwork
import DoomKitServices
import Foundation
import Testing

// URLs captured by executing the pre-extraction services with a recording fake.
struct ServiceCase: Sendable {
    let name: String
    let url: String
    let fetch: @Sendable (NetworkManager) async throws -> Data?

    static let all: [Self] = [
        Self(
            name: "CovidService.fetchDistricts",
            url:
                #"https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature&typeNames=vg250:vg250_krs&bbox=13.386771272770513,52.5089081027668,13.423228727229485,52.5310918972332,EPSG:4326&outputFormat=application/json&count=20"#,
            fetch: { manager in
                return try await CovidService.fetchDistricts(
                    for: Location(latitude: 52.52, longitude: 13.405), radius: 1234.75, networkManager: manager)
            }),
        Self(
            name: "CovidService.fetchIncidence", url: #"https://api.corona-zahlen.org/districts/fixture-123/history/incidence/1234"#,
            fetch: { manager in return try await CovidService.fetchIncidence(id: "fixture-123", duration: 1234.75, networkManager: manager) }),
        Self(
            name: "CovidService.fetchCases", url: #"https://api.corona-zahlen.org/districts/fixture-123/history/cases/1234"#,
            fetch: { manager in return try await CovidService.fetchCases(id: "fixture-123", duration: 1234.75, networkManager: manager) }),
        Self(
            name: "CovidService.fetchDeaths", url: #"https://api.corona-zahlen.org/districts/fixture-123/history/deaths/1234"#,
            fetch: { manager in return try await CovidService.fetchDeaths(id: "fixture-123", duration: 1234.75, networkManager: manager) }),
        Self(
            name: "CovidService.fetchRecovered", url: #"https://api.corona-zahlen.org/districts/fixture-123/history/recovered/1234"#,
            fetch: { manager in return try await CovidService.fetchRecovered(id: "fixture-123", duration: 1234.75, networkManager: manager) }),
        Self(
            name: "HazardService.fetchHazardList(mowas)", url: #"https://warnung.bund.de/api31/mowas/mapData.json"#,
            fetch: { manager in return try await HazardService.fetchHazardList(feed: .mowas, networkManager: manager) }),
        Self(
            name: "HazardService.fetchHazardList(dwd)", url: #"https://warnung.bund.de/api31/dwd/mapData.json"#,
            fetch: { manager in return try await HazardService.fetchHazardList(feed: .dwd, networkManager: manager) }),
        Self(
            name: "HazardService.fetchHazardList(katwarn)", url: #"https://warnung.bund.de/api31/katwarn/mapData.json"#,
            fetch: { manager in return try await HazardService.fetchHazardList(feed: .katwarn, networkManager: manager) }),
        Self(
            name: "HazardService.fetchHazardList(biwapp)", url: #"https://warnung.bund.de/api31/biwapp/mapData.json"#,
            fetch: { manager in return try await HazardService.fetchHazardList(feed: .biwapp, networkManager: manager) }),
        Self(
            name: "HazardService.fetchHazardDetails", url: #"https://warnung.bund.de/api31/warnings/fixture-123.json"#,
            fetch: { manager in return try await HazardService.fetchHazardDetails(for: "fixture-123", networkManager: manager) }),
        Self(
            name: "HazardService.fetchHazardRegion", url: #"https://warnung.bund.de/api31/warnings/fixture-123.geojson"#,
            fetch: { manager in return try await HazardService.fetchHazardRegion(for: "fixture-123", networkManager: manager) }),
        Self(
            name: "LevelService.fetchStations", url: #"https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations.json"#,
            fetch: { manager in return try await LevelService.fetchStations(networkManager: manager) }),
        Self(
            name: "LevelService.fetchMeasurements",
            url: #"https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations/fixture-123/W/measurements.json?start=P3D"#,
            fetch: { manager in return try await LevelService.fetchMeasurements(for: "fixture-123", networkManager: manager) }),
        Self(
            name: "LevelService.fetchForecast",
            url: #"https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations/fixture-123/WV/measurements.json"#,
            fetch: { manager in return try await LevelService.fetchForecast(for: "fixture-123", networkManager: manager) }),
        Self(
            name: "ParticleService.fetchStations",
            url:
                #"https://www.umweltbundesamt.de/api/air_data/v3/stations/json?use=airquality&lang=en&date_from=2024-01-02&time_from=16&date_to=2024-01-03&time_to=16"#,
            fetch: { manager in return try await ParticleService.fetchStations(from: Self.startDate, to: Self.endDate, networkManager: manager) }),
        Self(
            name: "ParticleService.fetchMeasurements",
            url:
                #"https://www.umweltbundesamt.de/api/air_data/v3/airquality/json?date_from=2024-01-02&time_from=16&date_to=2024-01-03&time_to=16&station=fixture-123"#,
            fetch: { manager in
                return try await ParticleService.fetchMeasurements(
                    code: "fixture-123", from: Self.startDate, to: Self.endDate, networkManager: manager)
            }),
        Self(
            name: "ParticleService.fetchForecasts",
            url:
                #"https://www.umweltbundesamt.de/api/air_data/v3/airqualityforecast/json?date_from=2024-01-02&time_from=16&date_to=2024-01-03&time_to=16&station=fixture-123"#,
            fetch: { manager in
                return try await ParticleService.fetchForecasts(
                    code: "fixture-123", from: Self.startDate, to: Self.endDate, networkManager: manager)
            }),
        Self(
            name: "PointOfInterestService.fetchPharmacies",
            url:
                #"https://overpass-api.de/api/interpreter?data=%5Bout:json%5D%5Btimeout:25%5D%5Bbbox:52.5089081027668,13.386771272770513,52.5310918972332,13.423228727229485%5D;%0A(%0A%20%20%20%20node%5B%22amenity%22=%22pharmacy%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22amenity%22=%22pharmacy%22%5D(around:1234.75,52.52,13.405);%0A)-%3E.pharmacies;%0A.pharmacies%20out%20center%20tags%20qt;"#,
            fetch: { manager in
                return try await PointOfInterestService.fetchPharmacies(
                    location: Location(latitude: 52.52, longitude: 13.405), radius: 1234.75, networkManager: manager)
            }),
        Self(
            name: "PointOfInterestService.fetchHospitals",
            url:
                #"https://overpass-api.de/api/interpreter?data=%5Bout:json%5D%5Btimeout:25%5D%5Bbbox:52.5089081027668,13.386771272770513,52.5310918972332,13.423228727229485%5D;%0A(%0A%20%20%20%20node%5B%22amenity%22=%22hospital%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22amenity%22=%22hospital%22%5D(around:1234.75,52.52,13.405);%0A)-%3E.hospitals;%0A.hospitals%20out%20center%20tags%20qt;"#,
            fetch: { manager in
                return try await PointOfInterestService.fetchHospitals(
                    location: Location(latitude: 52.52, longitude: 13.405), radius: 1234.75, networkManager: manager)
            }),
        Self(
            name: "PointOfInterestService.fetchLiquorStores",
            url:
                #"https://overpass-api.de/api/interpreter?data=%5Bout:json%5D%5Btimeout:25%5D%5Bbbox:52.5089081027668,13.386771272770513,52.5310918972332,13.423228727229485%5D;%0A(%0A%20%20%20%20node%5B%22shop%22=%22convenience%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22shop%22=%22convenience%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20node%5B%22shop%22=%22alcohol%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22shop%22=%22alcohol%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20node%5B%22shop%22=%22beverages%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22shop%22=%22beverages%22%5D(around:1234.75,52.52,13.405);%0A)-%3E.spatis;%0A.spatis%20out%20center%20tags%20qt;"#,
            fetch: { manager in
                return try await PointOfInterestService.fetchLiquorStores(
                    location: Location(latitude: 52.52, longitude: 13.405), radius: 1234.75, networkManager: manager)
            }),
        Self(
            name: "PointOfInterestService.fetchFuneralDirectors",
            url:
                #"https://overpass-api.de/api/interpreter?data=%5Bout:json%5D%5Btimeout:25%5D%5Bbbox:52.5089081027668,13.386771272770513,52.5310918972332,13.423228727229485%5D;%0A(%0A%20%20%20%20node%5B%22shop%22=%22funeral_directors%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22shop%22=%22funeral_directors%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20node%5B%22amenity%22=%22funeral_hall%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22amenity%22=%22funeral_hall%22%5D(around:1234.75,52.52,13.405);%0A)-%3E.funeral_homes;%0A.funeral_homes%20out%20center%20tags%20qt;"#,
            fetch: { manager in
                return try await PointOfInterestService.fetchFuneralDirectors(
                    location: Location(latitude: 52.52, longitude: 13.405), radius: 1234.75, networkManager: manager)
            }),
        Self(
            name: "PointOfInterestService.fetchCemeteries",
            url:
                #"https://overpass-api.de/api/interpreter?data=%5Bout:json%5D%5Btimeout:25%5D%5Bbbox:52.5089081027668,13.386771272770513,52.5310918972332,13.423228727229485%5D;%0A(%0A%20%20%20%20way%5B%22landuse%22=%22cemetery%22%5D(around:1234.75,52.52,13.405);%0A%20%20%20%20way%5B%22amenity%22=%22grave_yard%22%5D(around:1234.75,52.52,13.405);%0A)-%3E.graveyards;%0A.graveyards%20out%20center%20tags%20qt;"#,
            fetch: { manager in
                return try await PointOfInterestService.fetchCemeteries(
                    location: Location(latitude: 52.52, longitude: 13.405), radius: 1234.75, networkManager: manager)
            }),
        Self(
            name: "RadiationService.fetchStations",
            url:
                #"https://www.imis.bfs.de/ogc/opendata/ows?service=WFS&version=1.1.0&request=GetFeature&typeName=opendata:odlinfo_odl_1h_latest&outputFormat=application/json"#,
            fetch: { manager in return try await RadiationService.fetchStations(networkManager: manager) }),
        Self(
            name: "RadiationService.fetchMeasurements",
            url:
                #"https://www.imis.bfs.de/ogc/opendata/ows?service=WFS&version=1.1.0&request=GetFeature&typeName=opendata:odlinfo_timeseries_odl_1h&outputFormat=application/json&viewparams=kenn:fixture-123"#,
            fetch: { manager in return try await RadiationService.fetchMeasurements(for: "fixture-123", networkManager: manager) }),
        Self(
            name: "SurveyService.fetchStates",
            url:
                #"https://overpass-api.de/api/interpreter?data=%5Bout:json%5D%5Btimeout:25%5D;relation(around:10000,52.52,13.405)%5B%22boundary%22=%22administrative%22%5D%5B%22admin_level%22=%224%22%5D;out%20center%20tags;"#,
            fetch: { manager in
                return try await SurveyService.fetchStates(for: Location(latitude: 52.52, longitude: 13.405), networkManager: manager)
            }),
        Self(
            name: "SurveyService.fetchPolls", url: #"https://api.dawum.de"#,
            fetch: { manager in return try await SurveyService.fetchPolls(networkManager: manager) }),
        Self(
            name: "EnergyService.fetchBrent", url: #"https://raw.githubusercontent.com/datasets/oil-prices/main/data/brent-daily.csv"#,
            fetch: { manager in return try await EnergyService.fetchBrent(networkManager: manager) }),
        Self(
            name: "EnergyService.fetchWTI", url: #"https://raw.githubusercontent.com/datasets/oil-prices/main/data/wti-daily.csv"#,
            fetch: { manager in return try await EnergyService.fetchWTI(networkManager: manager) }),
        Self(
            name: "EnergyService.fetchLNG", url: #"https://aegis.acer.europa.eu/terminal/price_assessments/historical_data"#,
            fetch: { manager in return try await EnergyService.fetchLNG(networkManager: manager) }),
        // A fixture key, never a real one: the secret belongs in the keychain, not in a test.
        Self(
            name: "FuelService.fetchStations",
            url: #"https://creativecommons.tankerkoenig.de/json/list.php?lat=52.52&lng=13.405&rad=10.0&sort=dist&type=all&apikey=fixture-key"#,
            fetch: { manager in
                return try await FuelService.fetchStations(
                    location: Location(latitude: 52.52, longitude: 13.405), radius: 10.0, apiKey: "fixture-key", networkManager: manager)
            })
    ]

    static var startDate: Date {
        return Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 16, minute: 10)) ?? Date.distantPast
    }
    static var endDate: Date {
        return Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 3, hour: 17, minute: 40)) ?? Date.distantPast
    }
}
