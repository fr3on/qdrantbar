import AppKit
import QdrantBarCore

/// Draws the menu bar item: the QdrantBar mark and a status dot, then an optional stat.
///
/// It is one non-template image, because the dot needs its own color. The mark and the text are drawn with
/// `labelColor` at draw time, so they follow the menu bar's light or dark appearance.
enum MenuBarImage {
    private static let height: CGFloat = 18
    private static let glyphWidth: CGFloat = 18
    private static var font: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium) }
    private static var amber: NSColor { NSColor(red: 0.96, green: 0.72, blue: 0.24, alpha: 1) }

    static func make(_ display: MenuBarDisplay) -> NSImage {
        let textWidth = display.text.map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) } ?? 0
        let width = glyphWidth + (textWidth > 0 ? 3 + textWidth : 0) + 1
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            draw(display)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = display.tooltip
        return image
    }

    private static func draw(_ display: MenuBarDisplay) {
        let dim: CGFloat = display.state == .offline ? 0.45 : 1
        let ink = NSColor.labelColor.withAlphaComponent(0.9 * dim)

        // The mark, tinted with the current label color.
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let symbol = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) {
            let target = NSRect(x: 0, y: 2, width: 16, height: 14)
            let tinted = NSImage(size: target.size, flipped: false) { rect in
                symbol.draw(in: rect)
                ink.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: target)
        }

        // A clear halo behind the badge keeps it readable against the mark.
        let badge = NSRect(x: 10, y: 0, width: 7, height: 7)
        if let context = NSGraphicsContext.current {
            context.saveGraphicsState()
            context.compositingOperation = .clear
            NSBezierPath(ovalIn: badge.insetBy(dx: -1.6, dy: -1.6)).fill()
            context.restoreGraphicsState()
        }

        switch display.state {
        case .unauthorized:
            if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 7, weight: .bold)) {
                let tinted = NSImage(size: lock.size, flipped: false) { rect in
                    lock.draw(in: rect)
                    amber.set()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: NSRect(x: badge.midX - lock.size.width / 2, y: badge.midY - lock.size.height / 2, width: lock.size.width, height: lock.size.height))
            }
        default:
            dotColor(display.state).setFill()
            NSBezierPath(ovalIn: badge).fill()
        }

        if let text = display.text {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
            let size = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(at: NSPoint(x: glyphWidth + 3, y: (height - size.height) / 2), withAttributes: attributes)
        }
    }

    private static func dotColor(_ state: MenuBarDisplay.State) -> NSColor {
        switch state {
        case .online: return .systemGreen
        case .degraded, .unauthorized: return amber
        case .offline: return .systemGray
        }
    }
}
