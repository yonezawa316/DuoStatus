import AppKit

// Original DuoStatus artwork, drawn from geometric paths without external assets.
// This is a build-time utility. It is not linked into the running application.
enum IconTheme: String, CaseIterable {
    case light, dark

    var backgroundBottom: NSColor { color(dark: 0x11151C, light: 0xEDF2F5) }
    var backgroundTop: NSColor { color(dark: 0x222932, light: 0xFFFFFF) }
    var outline: NSColor { color(dark: 0x404752, light: 0xD7DFE5) }
    var foreground: NSColor { color(dark: 0xF4F8FA, light: 0x293744) }
    var track: NSColor { color(dark: 0x39444F, light: 0xD9E2E7) }
    var green: NSColor { color(dark: 0x47DC88, light: 0x20B36A) }
    var blue: NSColor { color(dark: 0x64B5FF, light: 0x288DE0) }

    private func color(dark: UInt32, light: UInt32) -> NSColor {
        let hex = self == .dark ? dark : light
        return NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                       green: CGFloat((hex >> 8) & 0xff) / 255,
                       blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

func strokeArc(center: NSPoint, radius: CGFloat, start: CGFloat, end: CGFloat,
               clockwise: Bool, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.appendArc(withCenter: center, radius: radius, startAngle: start,
                   endAngle: end, clockwise: clockwise)
    color.setStroke()
    path.stroke()
}

func drawIcon(theme: IconTheme) {
    let tileRect = NSRect(x: 88, y: 88, width: 848, height: 848)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: 190, yRadius: 190)

    // A restrained shadow and broad corners give the icon an application tile
    // silhouette while leaving the transparent outer margin intact.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(theme == .dark ? 0.24 : 0.14)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    theme.backgroundBottom.setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: theme.backgroundBottom, ending: theme.backgroundTop)!
        .draw(in: tile, angle: 90)
    theme.outline.withAlphaComponent(0.55).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    let center = NSPoint(x: 512, y: 522)
    let radius: CGFloat = 270
    let width: CGFloat = 58

    // Top battery sweep and lower memory sweep share one circle. Their two
    // gaps preserve the same recognisable silhouette as the menu bar mark.
    strokeArc(center: center, radius: radius, start: 210, end: -30,
              clockwise: true, width: width, color: theme.track)
    strokeArc(center: center, radius: radius, start: 210, end: -4,
              clockwise: true, width: width, color: theme.green)
    strokeArc(center: center, radius: radius, start: 234, end: 306,
              clockwise: false, width: width, color: theme.track)
    strokeArc(center: center, radius: radius, start: 234, end: 286,
              clockwise: false, width: width, color: theme.blue)

    // Two hand-drawn radio arcs and a dot; no SF Symbols or vendor artwork.
    let radioCenter = NSPoint(x: 512, y: 428)
    for radioRadius: CGFloat in [168, 92] {
        strokeArc(center: radioCenter, radius: radioRadius, start: 137, end: 43,
                  clockwise: true, width: 38, color: theme.foreground)
    }
    theme.foreground.setFill()
    NSBezierPath(ovalIn: NSRect(x: 491, y: 407, width: 42, height: 42)).fill()
}

func render(theme: IconTheme, pixels: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
        pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "DuoStatus.Icon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true
    context.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill(using: .copy)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()
    drawIcon(theme: theme)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DuoStatus.Icon", code: 2)
    }
    try data.write(to: url, options: .atomic)
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: GenerateAppIcons <icon-build-directory> <preview-directory>\n", stderr)
    exit(2)
}
let build = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let previews = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let manager = FileManager.default
try manager.createDirectory(at: previews, withIntermediateDirectories: true)
for theme in IconTheme.allCases {
    let iconset = build.appendingPathComponent("AppIcon-\(theme.rawValue).iconset", isDirectory: true)
    try manager.createDirectory(at: iconset, withIntermediateDirectories: true)
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let suffix = scale == 1 ? "" : "@2x"
            let file = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
            try autoreleasepool { try render(theme: theme, pixels: size * scale, to: file) }
        }
    }
    try autoreleasepool {
        try render(theme: theme, pixels: 512,
                   to: previews.appendingPathComponent("app-icon-\(theme.rawValue).png"))
    }
}
