import Foundation

/// One source of data the app shows, with the credit its licence asks for. Both About screens list these in this order.
///
/// The wording is the provider's own where it prescribes one (BKG, DAWUM, BfS, DWD), checked against their terms on September 26, 2026.
/// Apple Weather is not in the list: its mark and legal link come from WeatherKit at run time (`WeatherAttributionView`).
struct DataSource: Identifiable, Equatable {
    /// What the source is for in the app, such as "Radiation".
    let topic: String
    /// The credit as the licence asks for it.
    let attribution: String
    /// The licence, or nil where there is none to name.
    let licence: String?
    let licenceURL: URL?
    /// The provider's page.
    let sourceURL: URL?
    /// Whether the licence or terms require the credit. The others are credited as a courtesy.
    let isRequired: Bool

    var id: String { return self.topic }
}

enum DataSources {
    static let ccBy4 = URL(string: "https://creativecommons.org/licenses/by/4.0/")
    static let dlDeBy2 = URL(string: "https://www.govdata.de/dl-de/by-2-0")

    /// BKG asks for the year of the last retrieval. The districts are fetched on every COVID refresh, so that is the current year.
    static func all(year: Int = Calendar.current.component(.year, from: Date())) -> [DataSource] {
        return [
            DataSource(
                topic: "Warnings",
                attribution: "Official warnings from NINA, Bundesamt für Bevölkerungsschutz und Katastrophenhilfe (BBK), issued by MoWaS, "
                    + "KATWARN, BIWAPP and the Deutscher Wetterdienst. Shown unaltered with their source; DWD warnings: Quelle: Deutscher Wetterdienst.",
                licence: "Redistribution with source, § 5 Abs. 2 UrhG; DWD content CC BY 4.0", licenceURL: Self.ccBy4,
                sourceURL: URL(string: "https://warnung.bund.de"), isRequired: true),
            DataSource(
                topic: "COVID-19",
                attribution: "Robert Koch-Institut (RKI), via api.corona-zahlen.org by Marlon Lückert. District incidence as published.",
                licence: "CC BY 4.0", licenceURL: Self.ccBy4, sourceURL: URL(string: "https://api.corona-zahlen.org"), isRequired: true),
            DataSource(
                topic: "District Boundaries",
                attribution: "© BKG (\(year)) dl-de/by-2-0, Datenquellen: https://sgx.geodatenzentrum.de/web_public/gdz/datenquellen/datenquellen_vg_nuts.pdf",
                licence: "dl-de/by-2-0", licenceURL: Self.dlDeBy2, sourceURL: URL(string: "https://www.bkg.bund.de"), isRequired: true),
            DataSource(
                topic: "Berlin Boroughs",
                attribution: "Amt für Statistik Berlin-Brandenburg, Ortsteile merged into Bezirke by m-hoerz/berlin-shapes and the Berliner Morgenpost.",
                licence: "CC BY 3.0 DE, adapted", licenceURL: URL(string: "https://creativecommons.org/licenses/by/3.0/de/"),
                sourceURL: URL(string: "https://www.statistik-berlin-brandenburg.de"), isRequired: true),
            DataSource(
                topic: "Water Levels",
                attribution: "PEGELONLINE, Wasserstraßen- und Schifffahrtsverwaltung des Bundes (WSV).", licence: "DL-DE→Zero-2.0",
                licenceURL: URL(string: "https://www.govdata.de/dl-de/zero-2-0"), sourceURL: URL(string: "https://www.pegelonline.wsv.de"),
                isRequired: false),
            DataSource(
                topic: "Waterway Network",
                attribution: "VerkNet-BWaStr, Generaldirektion Wasserstraßen und Schifffahrt (GDWS), bundled with the app.", licence: "GeoNutzV",
                licenceURL: URL(string: "https://www.gesetze-im-internet.de/geonutzv/"),
                sourceURL: URL(string: "https://www.gdws.wsv.bund.de"), isRequired: false),
            DataSource(
                topic: "Radiation",
                attribution: "Quelle: © Bundesamt für Strahlenschutz (BfS), ODL-Messnetz.", licence: "GeoNutzV",
                licenceURL: URL(string: "https://www.gesetze-im-internet.de/geonutzv/"), sourceURL: URL(string: "https://odlinfo.bfs.de"),
                isRequired: true),
            DataSource(
                topic: "Air Quality",
                attribution: "Umweltbundesamt, air quality data of the measuring networks of the federal states and the federal government.",
                licence: "dl-de/by-2-0", licenceURL: Self.dlDeBy2, sourceURL: URL(string: "https://luftdaten.umweltbundesamt.de"),
                isRequired: true),
            DataSource(
                topic: "Crude Oil",
                attribution: "Source: U.S. Energy Information Administration (EIA), Brent and WTI spot prices, via datasets/oil-prices.",
                licence: "Public domain, ODC-PDDL", licenceURL: URL(string: "https://opendatacommons.org/licenses/pddl/1-0/"),
                sourceURL: URL(string: "https://www.eia.gov"), isRequired: false),
            DataSource(
                topic: "LNG",
                attribution: "Source: European Union Agency for the Cooperation of Energy Regulators (ACER), LNG price assessments, aegis.acer.europa.eu.",
                licence: "Reproduction with acknowledgement", licenceURL: URL(string: "https://www.acer.europa.eu/legal-notice"),
                sourceURL: URL(string: "https://aegis.acer.europa.eu"), isRequired: true),
            DataSource(
                topic: "Fuel Prices",
                attribution: "tankerkoenig.de, data from the Markttransparenzstelle für Kraftstoffe (MTS-K).", licence: "CC BY 4.0",
                licenceURL: Self.ccBy4, sourceURL: URL(string: "https://www.tankerkoenig.de"), isRequired: true),
            DataSource(
                topic: "Election Polls",
                attribution: "Daten von dawum.de (Open Database License (ODbL)).", licence: "ODbL 1.0",
                licenceURL: URL(string: "https://opendatacommons.org/licenses/odbl/1-0/"), sourceURL: URL(string: "https://dawum.de"),
                isRequired: true),
            DataSource(
                topic: "Places",
                attribution: "© OpenStreetMap contributors, queried through the Overpass API.", licence: "ODbL 1.0",
                licenceURL: URL(string: "https://www.openstreetmap.org/copyright"), sourceURL: URL(string: "https://overpass-api.de"),
                isRequired: true),
            DataSource(
                topic: "Maps and Addresses",
                attribution: "Apple Maps; the map shows its own legal notice.", licence: nil, licenceURL: nil, sourceURL: nil, isRequired: false),
        ]
    }

    /// The source note the GeoNutzV asks for "in optischem Zusammenhang" with the data, so it sits under the radiation charts as well.
    static let radiationNote = "Quelle: © Bundesamt für Strahlenschutz"

    /// WeatherKit may not be used in an app designed or marketed for emergencies, and the app shows official warnings, so both About
    /// screens say plainly what the warnings are not.
    static let disclaimer =
        "Not for emergencies or life-saving decisions. Warnings are shown as issued, but may be delayed or incomplete; follow the official "
        + "channels, NINA and the Deutscher Wetterdienst, and the instructions of the authorities."
}
