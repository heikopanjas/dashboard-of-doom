#if os(macOS)
import AppKit

/// The content of the macOS status item: a small vertical "DOD" tag, then one value at the size of menu bar text, or two stacked in a
/// smaller font. Ported from senor-particle's `StatusItemDisplayView` (github.com/heikopanjas/senor-particle), where the tag names the
/// device; here it always names the app.
final class StatusItemDisplayView: NSView {
    static let tag = "DOD"

    private static let tagFont = NSFont.monospacedSystemFont(ofSize: 6.5, weight: .semibold)
    private static let singleValueFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    private static let stackedValueFont = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)
    private static let horizontalPadding: CGFloat = 3
    private static let tagValueGap: CGFloat = 3
    private static let tagWidth: CGFloat = 7

    private var values: [String] = []

    override var isFlipped: Bool { return true }

    /// Clicks go to the status item's button underneath, which opens the menu.
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    func configure(values: [String]) -> Void {
        self.values = values
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) -> Void {
        super.draw(dirtyRect)
        guard self.values.isEmpty == false else { return }
        self.drawTag(x: Self.horizontalPadding)
        self.drawValues(x: Self.horizontalPadding + Self.tagWidth + Self.tagValueGap)
    }

    static func requiredWidth(for values: [String]) -> CGFloat {
        guard values.isEmpty == false else { return 0 }
        let font = Self.valueFont(for: values.count)
        let widest = values.map { ceil(NSAttributedString(string: $0, attributes: [.font: font]).size().width) }.max() ?? 0
        return ceil(Self.horizontalPadding * 2 + Self.tagWidth + Self.tagValueGap + widest)
    }

    /// The tag's letters one under the other, centred in their column, in the secondary label color.
    private func drawTag(x: CGFloat) -> Void {
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.tagFont, .foregroundColor: NSColor.secondaryLabelColor]
        let lineHeight = Self.tagFont.ascender - Self.tagFont.descender
        var y = max((self.bounds.height - CGFloat(Self.tag.count) * lineHeight) / 2, 0)
        for character in Self.tag {
            let letter = NSAttributedString(string: String(character), attributes: attributes)
            letter.draw(at: NSPoint(x: x + (Self.tagWidth - letter.size().width) / 2, y: y))
            y += lineHeight
        }
    }

    private func drawValues(x: CGFloat) -> Void {
        let font = Self.valueFont(for: self.values.count)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let rowHeight = font.ascender - font.descender
        var y = max((self.bounds.height - CGFloat(self.values.count) * rowHeight) / 2, 0) - 0.5
        for value in self.values {
            NSAttributedString(string: value, attributes: attributes).draw(at: NSPoint(x: x, y: y))
            y += rowHeight
        }
    }

    private static func valueFont(for count: Int) -> NSFont {
        return count == 1 ? Self.singleValueFont : Self.stackedValueFont
    }
}
#endif
