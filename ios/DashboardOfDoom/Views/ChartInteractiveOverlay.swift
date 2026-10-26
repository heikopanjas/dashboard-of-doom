import Charts
import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import SwiftUI

extension View {
    func chartInteractiveOverlay(
        timestamp: Binding<Date?>,
        roundingStrategy: RoundingStrategy
    ) -> some View {
        modifier(
            ChartInteractiveOverlayModifier(
                timestamp: timestamp,
                roundingStrategy: roundingStrategy
            ))
    }
}

private struct ChartInteractiveOverlayModifier: ViewModifier {
    @Binding var timestamp: Date?
    let roundingStrategy: RoundingStrategy

    func body(content: Content) -> some View {
        content
            .chartOverlay { geometryProxy in
                GeometryReader { geometryReader in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            SimultaneousSwipeGesture(
                                roundingStrategy: roundingStrategy,
                                onChanged: { recognizer, translation in
                                    let horizontalAmount = abs(translation.width)
                                    let verticalAmount = abs(translation.height)
                                    if horizontalAmount > verticalAmount * 2.0 {
                                        if let plotFrame = geometryProxy.plotFrame {
                                            let location = recognizer.location(in: recognizer.view)
                                            let x = location.x - geometryReader[plotFrame].origin.x
                                            if let source: Date = geometryProxy.value(atX: x) {
                                                if let target = Date.round(from: source, strategy: roundingStrategy) {
                                                    timestamp = target
                                                }
                                            }
                                        }
                                    }
                                },
                                onEnded: { _, _ in
                                    timestamp = nil
                                }
                            )
                        )
                }
            }
    }
}
