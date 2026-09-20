import SwiftUI

extension Gradient {
#if os(macOS)
    static let linear = LinearGradient(
        gradient: Gradient(colors: [
            Color.chart.opacity(1.0),
            Color.chart.opacity(0.23)
        ]),
        startPoint: .top,
        endPoint: .bottom)
#else
    static let linear = LinearGradient(
        gradient: Gradient(colors: [
            Color.chart.opacity(0.67),
            Color.chart.opacity(0.0)
        ]),
        startPoint: .top,
        endPoint: .bottom)
#endif

    static let fascists = LinearGradient(
        gradient: Gradient(colors: [
            Color.fascists.opacity(1.0),
            Color.fascists.opacity(0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let clowns = LinearGradient(
        gradient: Gradient(colors: [
            Color.clowns.opacity(1.0),
            Color.clowns.opacity(0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let rainbow = LinearGradient(
        stops: [
            Gradient.Stop(color: .blue, location: 0),
            Gradient.Stop(color: .blue.opacity(0.5), location: 0.125),
            Gradient.Stop(color: .yellow, location: 0.25),
            Gradient.Stop(color: .orange, location: 0.5),
            Gradient.Stop(color: .red, location: 0.75),
            Gradient.Stop(color: .purple, location: 1.0)
        ],
        startPoint: .bottom, endPoint: .top)

    static let cducsu = LinearGradient(
        gradient: Gradient(colors: [
            .blue.opacity(1.0),
            .blue.opacity(0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let spd = LinearGradient(
        gradient: Gradient(colors: [
            .red.opacity(1.0),
            .red.opacity(0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let gruene = LinearGradient(
        gradient: Gradient(colors: [
            .green.opacity(1.0),
            .green.opacity(0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let linke = LinearGradient(
        gradient: Gradient(colors: [
            .purple.opacity(1.0),
            .purple.opacity(0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let sonstige = LinearGradient(
        gradient: Gradient(colors: [
            .gray.opacity(1.0),
            .gray.opacity(0.33)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
}
