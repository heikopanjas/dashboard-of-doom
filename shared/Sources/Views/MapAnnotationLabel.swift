import DoomKitProcess
import DoomKitTools
import SwiftUI

/// Shared with the screen-space solver, including both layers of padding.
struct MapAnnotationLabel: View {
    let selector: ProcessSelector
    let icon: String
    let faceplate: String
    var backgroundOpacity: Double = 0.5

    static var size: CGSize {
        #if os(iOS)
        return CGSize(width: 132, height: 36)
        #else
        return AnnotationLayout.labelSize
        #endif
    }

    private static var horizontalPadding: CGFloat {
        #if os(iOS)
        return 5
        #else
        return 10
        #endif
    }

    var body: some View {
        Group {
            #if os(iOS)
            HStack(spacing: 4) {
                Image(systemName: self.icon)
                    .font(.title3)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(self.faceplate)
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)
            }
            // Fixed-size map labels retain readable bounds; VoiceOver exposes the full value.
            .dynamicTypeSize(...DynamicTypeSize.large)
            #else
            HStack {
                Image(systemName: self.icon)
                    .accessibilityHidden(true)
                Text(self.faceplate)
            }
            #endif
        }
        .frame(width: Self.size.width - 2 * Self.horizontalPadding, height: Self.size.height - 10)
        .padding(.vertical, 5)
        .padding(.horizontal, Self.horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.faceplate(selector: self.selector))
                .opacity(self.backgroundOpacity)
        )
        .foregroundStyle(.black)
        .accessibilityElement(children: .combine)
    }
}
