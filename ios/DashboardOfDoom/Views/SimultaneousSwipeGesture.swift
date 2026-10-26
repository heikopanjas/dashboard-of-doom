import DoomKitLocation
import DoomKitProcess
import DoomKitTools
import SwiftUI

struct SimultaneousSwipeGesture: UIGestureRecognizerRepresentable {
    let roundingStrategy: RoundingStrategy
    var onChanged: (UILongPressGestureRecognizer, CGSize) -> Void
    var onEnded: (UILongPressGestureRecognizer, CGSize) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleGesture(_:))
        )
        recognizer.minimumPressDuration = 0
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (UILongPressGestureRecognizer, CGSize) -> Void
        var onEnded: (UILongPressGestureRecognizer, CGSize) -> Void
        var initialLocation: CGPoint = .zero

        init(
            onChanged: @escaping (UILongPressGestureRecognizer, CGSize) -> Void,
            onEnded: @escaping (UILongPressGestureRecognizer, CGSize) -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handleGesture(_ recognizer: UILongPressGestureRecognizer) {
            let location = recognizer.location(in: recognizer.view)

            switch recognizer.state {
                case .began:
                    initialLocation = location
                case .changed:
                    let translation = CGSize(
                        width: location.x - initialLocation.x,
                        height: location.y - initialLocation.y
                    )
                    onChanged(recognizer, translation)
                case .ended, .cancelled:
                    let translation = CGSize(
                        width: location.x - initialLocation.x,
                        height: location.y - initialLocation.y
                    )
                    onEnded(recognizer, translation)
                default:
                    break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }
    }
}
