// Generates Resources/AppIcon.icns from Cup.swift:  scripts/make-icon.sh
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

func png(_ px: Int, to path: String) {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let s = CGFloat(px)
    ctx.translateBy(x: 0, y: s); ctx.scaleBy(x: 1, y: -1)           // y-down like Cup
    let tile = CGRect(x: s * 0.098, y: s * 0.098, width: s * 0.804, height: s * 0.804)
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: tile.width * 0.2237, cornerHeight: tile.width * 0.2237, transform: nil))
    ctx.setFillColor(CGColor(red: 0.94, green: 0.97, blue: 1, alpha: 1)); ctx.fillPath()
    let k = tile.width * 0.62 / Cup.box.width
    ctx.translateBy(x: s / 2 - Cup.box.width * k / 2, y: s / 2 - Cup.box.height * k / 2)
    ctx.scaleBy(x: k, y: k); ctx.translateBy(x: -Cup.box.minX, y: -Cup.box.minY)
    ctx.setStrokeColor(CGColor(red: 0.29, green: 0.52, blue: 0.9, alpha: 1))
    ctx.setLineWidth(Cup.lineWidth); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.addPath(Cup.body); ctx.addPath(Cup.handle); ctx.addPath(Cup.steam(nil)); ctx.strokePath()
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil); CGImageDestinationFinalize(d)
}

let out = CommandLine.arguments[1]
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    png(px, to: "\(out)/icon_\(name).png")
}
