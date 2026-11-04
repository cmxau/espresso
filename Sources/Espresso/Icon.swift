import AppKit

/// Menu bar image. `steam == nil` -> plain cup (off); otherwise cup with steam (animated by phase).
/// Frames are rendered once into 2x bitmaps and cached, so animating is just swapping a ready image.
enum Icon {
    private static var cache: [String: NSImage] = [:]

    static func image(steam: CGFloat?, color: NSColor?) -> NSImage {
        let key = "\(steam.map { String(format: "%.2f", $0) } ?? "-")|\(color?.hexKey ?? "-")"
        if let hit = cache[key] { return hit }
        if cache.count > 64 { cache.removeAll() }
        let img = render(steam: steam, color: color)
        cache[key] = img
        return img
    }

    private static func render(steam: CGFloat?, color: NSColor?) -> NSImage {
        let pts = NSSize(width: 21, height: 17), scale = 2
        let w = Int(pts.width) * scale, h = Int(pts.height) * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)            // y-down, in pixels
        let s = min(CGFloat(w) / Cup.box.width, CGFloat(h) / Cup.box.height)
        ctx.translateBy(x: (CGFloat(w) - Cup.box.width * s) / 2, y: (CGFloat(h) - Cup.box.height * s) / 2)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -Cup.box.minX, y: -Cup.box.minY)
        ctx.setStrokeColor((color ?? .black).cgColor)
        ctx.setLineWidth(Cup.lineWidth)
        ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.addPath(Cup.body); ctx.addPath(Cup.handle)
        if let steam { ctx.addPath(Cup.steam(steam)) }
        ctx.strokePath()
        NSGraphicsContext.restoreGraphicsState()
        rep.size = pts
        let img = NSImage(size: pts)
        img.addRepresentation(rep)
        img.isTemplate = color == nil
        return img
    }
}

private extension NSColor {
    var hexKey: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
