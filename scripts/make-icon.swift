// Usage: swift scripts/make-icon.swift <icon-1024.png> <logo-512.png>
// Draws the QdrantBar artwork: an indigo tile with the point-cluster mark used across the app.
//   icon: the tile on the standard macOS icon grid (824pt rounded square in a 1024pt canvas, with a soft shadow)
//   logo: the tile alone on a transparent 512pt canvas, for the README
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <icon-1024.png> <logo-512.png>\n".utf8))
    exit(1)
}

func bitmap(_ side: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

/// The tile, drawn into `rect` (a square). `shadow` adds the soft drop shadow macOS icons carry.
func drawTile(in rect: CGRect, shadow: Bool) {
    let radius = rect.width * 0.2237
    let plate = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    if shadow {
        NSGraphicsContext.saveGraphicsState()
        let drop = NSShadow()
        drop.shadowColor = NSColor.black.withAlphaComponent(0.32)
        drop.shadowOffset = NSSize(width: 0, height: -rect.width * 0.014)
        drop.shadowBlurRadius = rect.width * 0.03
        drop.set()
        rgb(0x4B4EC4).setFill()
        plate.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.saveGraphicsState()
    plate.addClip()

    // Body: light indigo top-left to deep indigo bottom-right.
    NSGradient(colors: [rgb(0x8B8FFF), rgb(0x6366F1), rgb(0x4338CA)], atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!
        .draw(in: plate, angle: -55)

    // A soft highlight over the upper half gives the tile some depth.
    let highlight = NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.20), NSColor.white.withAlphaComponent(0)])!
        .draw(in: highlight, angle: -90)

    // The mark: the same SF Symbol the menu bar and popover use, drawn large in white with a slight shadow.
    let pointSize = rect.width * 0.58
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) {
        let size = symbol.size
        let target = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        let white = NSImage(size: size, flipped: false) { bounds in
            symbol.draw(in: bounds)
            NSColor.white.set()
            bounds.fill(using: .sourceAtop)
            return true
        }
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor(red: 0.10, green: 0.08, blue: 0.45, alpha: 0.45)
        glow.shadowOffset = NSSize(width: 0, height: -rect.width * 0.012)
        glow.shadowBlurRadius = rect.width * 0.025
        glow.set()
        white.draw(in: target)
        NSGraphicsContext.restoreGraphicsState()
    } else {
        FileHandle.standardError.write(Data("SF Symbol not available on this system\n".utf8))
        exit(1)
    }

    NSGraphicsContext.restoreGraphicsState()

    // Hairline inner border.
    rgb(0xFFFFFF, 0.14).setStroke()
    let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius - 1, yRadius: radius - 1)
    border.lineWidth = max(1, rect.width * 0.002)
    border.stroke()
}

func write(_ rep: NSBitmapImageRep, to path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func render(side: Int, tile: CGRect, shadow: Bool, to path: String) {
    let rep = bitmap(side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawTile(in: tile, shadow: shadow)
    NSGraphicsContext.restoreGraphicsState()
    write(rep, to: path)
}

render(side: 1024, tile: CGRect(x: 100, y: 100, width: 824, height: 824), shadow: true, to: args[1])
render(side: 512, tile: CGRect(x: 0, y: 0, width: 512, height: 512), shadow: false, to: args[2])
