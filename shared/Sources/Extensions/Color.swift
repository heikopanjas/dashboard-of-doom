import DoomKitProcess
import SwiftUI

extension Color {
    #if os(macOS)
    init(light: Color, dark: Color) {
        self.init(
            NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    if let appearance = NSApp.appearance, appearance.name == .darkAqua {
                        return NSColor(dark)
                    }
                    else {
                        return NSColor(light)
                    }
                }
            )
        )
    }

    static let blendedBlue = Color(red: 0.33, green: 0.67, blue: 1.0)
    #else
    init(light: Color, dark: Color) {
        self.init(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(dark)
                    : UIColor(light)
            }
        )
    }

    static let blendedBlue = Color(red: 0.33, green: 0.67, blue: 1.0)
    #endif
}

extension Color {
    #if os(macOS)
    static let location: Color = Color(light: Color.blue, dark: Color.cyan)
    static let userLocation: Color = Color(light: Color.white, dark: Color.orange)
    static let faceplate = Color(light: Color.blendedBlue, dark: Color.cyan)
    static let chart = Color(light: Color.blendedBlue, dark: Color.cyan)
    static let spaeti = Color(light: Color.blendedBlue, dark: Color.cyan.opacity(0.5))
    static let treshold = Color(light: Color.black.opacity(0.33), dark: Color.white.opacity(0.33))
    #else
    static let location: Color = .accentColor
    static let userLocation: Color = .accentColor
    static let faceplate = Self.accentColor
    static let chart = Self.accentColor
    static let spaeti = Self.accentColor
    static let treshold = Self.accentColor.opacity(0.5)
    #endif

    static let brandPrimary = Color(hex: "#FF5733")  // Using hex code

    // Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
            case 3:  // RGB (12-bit)
                (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6:  // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8:  // ARGB (32-bit)
                (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let fascists = Color(red: 0.4, green: 0.2, blue: 0.1)
    static let clowns = Color(red: 0.8, green: 0.6, blue: 0.0)

    static let weather = Color.blue
    static let covid = Color.purple
    static let water = Color.yellow
    static let particle = Color.green
    static let radiation = Color.orange
    static let survey = Color.pink
    static let energy = Color.brown

    static func faceplate(selector: ProcessSelector) -> Color {
        switch selector {
            case .weather:
                return Self.weather
            case .forecast:
                return Self.weather
            case .covid:
                return Self.covid
            case .water:
                return Self.water
            case .particle:
                return Self.particle
            case .radiation:
                return Self.radiation
            case .survey:
                return Self.survey
            case .energy:
                return Self.energy
        }
    }

    /// The colors of the level gauges and radiation stations on the Environment tab, nearest first. Together they are the six label colors of
    /// the home screen, so no sensor has a color of its own. The nearest of each source keeps the color it has on the home map, orange for
    /// radiation and yellow for level, and the others take the four that are left.
    static let radiationSensors: [Color] = [Self.radiation, Self.survey, Self.covid]
    static let waterSensors: [Color] = [Self.water, Self.particle, Self.weather]
    /// The Particles tab is a tab of its own, so its stations can reuse colors: the nearest keeps the home particle color.
    static let particleSensors: [Color] = [Self.particle, Self.survey, Self.weather]

    /// The six filling stations on the Energy map, one colour each, which is why the map shows six. All six home label colours, warm
    /// first, so the dearest end of the list reads hot and the cheapest end cool. The colour marks the rank, not the price itself.
    static let fuelStations: [Color] = [Self.radiation, Self.survey, Self.water, Self.particle, Self.weather, Self.covid]

    /// The color of the sensor at `index` in its source's list, nearest first. A selector that has no such list keeps its category color,
    /// and an index past the end of a list wraps, so a longer list would repeat colors rather than fail.
    static func sensor(selector: ProcessSelector, index: Int) -> Color {
        let colors: [Color]
        switch selector {
            case .radiation:
                colors = Self.radiationSensors
            case .water:
                colors = Self.waterSensors
            case .particle:
                colors = Self.particleSensors
            default:
                return Self.faceplate(selector: selector)
        }
        return colors[((index % colors.count) + colors.count) % colors.count]
    }
}
