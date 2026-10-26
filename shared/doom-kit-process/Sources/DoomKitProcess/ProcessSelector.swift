import Foundation

public enum ProcessSelector: Hashable {
    case weather(Weather)
    case forecast(Forecast)
    case covid(Covid)
    case water(Water)
    case particle(Particle)
    case radiation(Radiation)
    case survey(Survey)
    case energy(Energy)

    public enum Weather: Int, CaseIterable {
        case temperature = 0
        case apparentTemperature = 1
        case dewPoint = 2
        case humidity = 3
        case precipitationIntensity = 4
        case pressure = 5
        case visibility = 6
        case cloudCover = 7
        case cloudCoverLow = 8
        case cloudCoverMedium = 9
        case cloudCoverHigh = 10
        case windSpeed = 11
        case windGust = 12
    }

    public enum Forecast: Int, CaseIterable {
        case temperature = 0
        case apparentTemperature = 1
        case dewPoint = 2
        case humidity = 3
        case precipitationChance = 4
        case precipitationAmount = 5
        case snowfallAmount = 6
        case pressure = 7
        case visibility = 8
        case cloudCover = 9
        case windSpeed = 10
        case windGust = 11
    }

    public enum Covid: Int, CaseIterable {
        case incidence = 0
        case cases = 1
        case deaths = 2
        case recovered = 3
    }

    public static func covid(from rawValue: Int) -> ProcessSelector? {
        guard let covid = Covid(rawValue: rawValue) else {
            return nil
        }
        return .covid(covid)
    }

    public enum Water: Int, CaseIterable {
        case level = 0  // W, WASSERSTAND, cm
        case waterTemperature = 1  // WT, WASSERTEMPERATUR, °C
        case electricalConductivity = 2  // LF, ELEKTRISCHE LEITFÄHIGKEIT, mS/cm
        case discharge = 3  // Q, ABFLUSS, m³/s
        case clearanceHeight = 4  // DFH, DURCHFAHRTSHÖHE, cm
        case airTemperature = 5  // LT, LUFTTEMPERATUR, °C
        case flowVelocity = 6  // VA, FLIESSGESCHWINDIGKEIT, m/s
        case groundWater = 7  // GRU, GRUNDWASSER, m
        case windSpeed = 8  // WG, WINDGESCHWINDIGKEIT, m/s
        case humidity = 9  // HL, LUFTFEUCHTE, %
        case oxygenConcentration = 10  // O2, SAUERSTOFFGEHALT, mg/l
        case turbity = 11  // TR, TRÜBUNG, FNU
        case windDirection = 12  // WR, WINDRICHTUNG, °
        case salinity = 13  // S, SALINITÄT, %
        case precipitation = 14  // NIEDERSCHLAG, NIEDERSCHLAG, mm
        case precipitationIntensity = 15  // NIEDERSCHLAGSINTENSITÄT, NIEDERSCHLAGSINTENSITÄT, mm/h
        case wavePeriod = 16  // TP, WELLENPERIODE, s
        case significantWaveHeight = 17  // SIGH, SIGNIFIKANTEWELLENHÖHE, m
        case maximumWaveHeight = 18  // MAXH, MAXIMALEWELLENHÖHE, m
        case primarySwellDirection = 19  // DIRTP, RICHTUNG HAUPTSEEGANG, °
        case flowDirection = 20  // RV, STRÖMUNGSRICHTUNG, °
        case pH = 21  // PH, PH-WERT, ---
        case chloride = 22  // CL, CHLORID, mg/l
    }

    public static func water(from rawValue: Int) -> ProcessSelector? {
        guard let water = Water(rawValue: rawValue) else {
            return nil
        }
        return .water(water)
    }

    public enum Radiation: Int, CaseIterable {
        case total = 0
        case cosmic = 1
        case terrestrial = 2
    }

    public enum Particle: Int, CaseIterable, RawRepresentable {
        case all = -1
        case pm10 = 1  // Particulate matter < 10µm
        case pm25 = 9  // Particulate matter < 2.5µm
        case o3 = 3  // Ozone
        case no2 = 5  // Nitrogen dioxide
        case co = 2  // Carbon monoxide
        case so2 = 4  // Sulfur dioxide
        case lead = 6  // Lead in particulate matter < 10µm
        case benzoapyrene = 7  // Benzo(a)pyrene in particulate matter < 10µm
        case benzene = 8  // Benzene
        case arsenic = 10  // Arsenic in particulate matter < 10µm
        case cadmium = 11  // Cadmium in particulate matter < 10µm
        case nickel = 12  // Nickel in particulate matter < 10µm
    }

    public static func particle(from rawValue: Int) -> ProcessSelector? {
        guard let particle = Particle(rawValue: rawValue) else {
            return nil
        }
        return .particle(particle)
    }

    public enum Survey: Int, CaseIterable, RawRepresentable {
        case fascists = 999
        case clowns = 998
        case linke = 5
        case gruene = 4
        case spd = 2
        case fdp = 3
        case afd = 7
        case bsw = 23
        case cducsu = 1
        case cdu = 101
        case csu = 102
        case piraten = 6
        case freieWaehler = 8
        case npd = 9
        case ssw = 10
        case bayernpartei = 11
        case oedp = 12
        case partei = 13
        case bvbFw = 14
        case tierschutz = 15
        case biw = 16
        case familie = 17
        case volt = 18
        case buntSaar = 21
        case bfth = 22
        case plusBrandenburg = 24
        case werteUnion = 25
        case sonstige = 0
    }

    public static func survey(from rawValue: Int) -> ProcessSelector? {
        guard let survey = Survey(rawValue: rawValue) else {
            return nil
        }
        return .survey(survey)
    }

    /// Global energy prices, crude oil in US dollars per barrel and gas in euros per megawatt hour, and Germany's monthly fuel stocks in
    /// days of supply.
    public enum Energy: Int, CaseIterable {
        case brentSpot = 3
        case brent = 0
        case ttf = 4
        // Keep LNG's existing identifier; 1 belonged to the retired WTI series.
        case lng = 2
        case petrolStock = 5
        case dieselStock = 6
        case jetFuelStock = 7

        /// A stock is a monthly level, not a daily price, so it is charted, rounded and estimated differently.
        public var isStock: Bool {
            switch self {
                case .petrolStock:
                    return true
                case .dieselStock:
                    return true
                case .jetFuelStock:
                    return true
                case .brentSpot:
                    return false
                case .brent:
                    return false
                case .ttf:
                    return false
                case .lng:
                    return false
            }
        }
    }

    public static func energy(from rawValue: Int) -> ProcessSelector? {
        guard let energy = Energy(rawValue: rawValue) else {
            return nil
        }
        return .energy(energy)
    }

    public var rawValue: Int {
        switch self {
            case .weather(let weatherType):
                return weatherType.rawValue
            case .forecast(let forecastType):
                return forecastType.rawValue
            case .covid(let covidType):
                return covidType.rawValue
            case .water(let waterType):
                return waterType.rawValue
            case .particle(let particleType):
                return particleType.rawValue
            case .radiation(let radiationType):
                return radiationType.rawValue
            case .survey(let surveyType):
                return surveyType.rawValue
            case .energy(let energyType):
                return energyType.rawValue
        }
    }
}
