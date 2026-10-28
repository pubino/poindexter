// Draws the Poindexter app icon: a pair of glasses resting on a desk.
// The art is an opaque, full-bleed square so macOS (Tahoe and later) masks it to fill the
// whole squircle — no transparent margin, no baked-in rounded corners.
// Usage: swift run make-icon output.png
import AppKit
import CoreGraphics

let size = 1024.0
guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon output.png\n".utf8))
    exit(2)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

@MainActor func linear(_ colors: [UInt32], from: CGPoint, to: CGPoint, clip: CGPath) {
    ctx.saveGState()
    ctx.addPath(clip)
    ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: colors.map { rgb($0) } as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

// Core Graphics' origin is bottom-left. The desk occupies the lower 42%.
let deskTop = size * 0.42

// Wall: calm blue, lighter toward the top.
linear([0x2B5C8A, 0x5D9BD0], from: CGPoint(x: 0, y: deskTop), to: CGPoint(x: 0, y: size),
       clip: CGPath(rect: CGRect(x: 0, y: deskTop, width: size, height: size - deskTop), transform: nil))

// Desk: warm wood with a lit front edge and a few grain lines.
let desk = CGRect(x: 0, y: 0, width: size, height: deskTop)
linear([0x6E3B1E, 0xA8693A], from: .zero, to: CGPoint(x: 0, y: deskTop), clip: CGPath(rect: desk, transform: nil))
ctx.setFillColor(rgb(0xD69A62))
ctx.fill(CGRect(x: 0, y: deskTop - 18, width: size, height: 18))
ctx.setStrokeColor(rgb(0x5A2E15, 0.35))
ctx.setLineWidth(6)
for (y, bend) in [(300.0, 18.0), (210.0, -14.0), (120.0, 22.0), (45.0, -10.0)] {
    ctx.move(to: CGPoint(x: -20, y: y))
    ctx.addCurve(to: CGPoint(x: size + 20, y: y + bend), control1: CGPoint(x: size * 0.33, y: y + bend * 2),
                 control2: CGPoint(x: size * 0.66, y: y - bend))
    ctx.strokePath()
}

// Glasses, seen from the front, resting on the desk.
let lensW = 330.0, lensH = 250.0, gap = 92.0, lensY = deskTop - 70
let leftLens = CGRect(x: size / 2 - gap / 2 - lensW, y: lensY, width: lensW, height: lensH)
let rightLens = CGRect(x: size / 2 + gap / 2, y: lensY, width: lensW, height: lensH)
let frame = rgb(0x1B1B22)

// Soft shadow on the desk under the glasses.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 40, color: rgb(0x000000, 0.55))
ctx.setFillColor(rgb(0x3A1E0E, 0.6))
ctx.fillEllipse(in: CGRect(x: leftLens.minX - 30, y: lensY - 45, width: rightLens.maxX - leftLens.minX + 60, height: 70))
ctx.restoreGState()

// Temples (arms) folded back, drawn first so the front frame overlaps them.
ctx.setStrokeColor(frame)
ctx.setLineWidth(30)
ctx.setLineCap(.round)
for (start, end) in [
    (CGPoint(x: leftLens.minX + 10, y: lensY + lensH - 40), CGPoint(x: leftLens.minX + 150, y: lensY + lensH + 70)),
    (CGPoint(x: rightLens.maxX - 10, y: lensY + lensH - 40), CGPoint(x: rightLens.maxX - 150, y: lensY + lensH + 70)),
] {
    ctx.move(to: start)
    ctx.addLine(to: end)
    ctx.strokePath()
}

for lens in [leftLens, rightLens] {
    let path = CGPath(roundedRect: lens, cornerWidth: 110, cornerHeight: 110, transform: nil)
    // Tinted glass, slightly lighter at the top.
    linear([0x9CC9EE, 0xE4F3FF], from: CGPoint(x: 0, y: lens.minY), to: CGPoint(x: 0, y: lens.maxY), clip: path)
    // Diagonal glint.
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.setFillColor(rgb(0xFFFFFF, 0.55))
    ctx.move(to: CGPoint(x: lens.minX + 60, y: lens.maxY))
    ctx.addLine(to: CGPoint(x: lens.minX + 130, y: lens.maxY))
    ctx.addLine(to: CGPoint(x: lens.minX + 20, y: lens.minY + 40))
    ctx.addLine(to: CGPoint(x: lens.minX - 50, y: lens.minY + 40))
    ctx.fillPath()
    ctx.restoreGState()
    // Thick frame.
    ctx.addPath(path)
    ctx.setStrokeColor(frame)
    ctx.setLineWidth(40)
    ctx.strokePath()
}

// Bridge.
ctx.setLineWidth(34)
ctx.move(to: CGPoint(x: leftLens.maxX - 6, y: lensY + lensH * 0.62))
ctx.addQuadCurve(to: CGPoint(x: rightLens.minX + 6, y: lensY + lensH * 0.62),
                 control: CGPoint(x: size / 2, y: lensY + lensH * 0.95))
ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
