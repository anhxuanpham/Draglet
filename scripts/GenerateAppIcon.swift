// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit

// Deterministic vector artwork, rendered at every macOS app-icon size.
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Draglet/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
var entries: [[String: String]] = []

func drawIcon() {
    let background = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 208, yRadius: 208)
    NSGradient(colors: [NSColor(red: 0.16, green: 0.69, blue: 0.93, alpha: 1), NSColor(red: 0.18, green: 0.34, blue: 0.80, alpha: 1)])!.draw(in: background, angle: -70)

    NSColor.black.withAlphaComponent(0.12).setFill()
    NSBezierPath(roundedRect: NSRect(x: 239, y: 221, width: 562, height: 395), xRadius: 66, yRadius: 66).fill()

    for (offset, color) in [(CGFloat(-60), NSColor.white.withAlphaComponent(0.65)), (CGFloat(0), NSColor.white)] {
        let paper = NSBezierPath(roundedRect: NSRect(x: 348 + offset, y: 390, width: 348, height: 362), xRadius: 35, yRadius: 35)
        color.setFill()
        paper.fill()
    }
    NSColor(red: 0.64, green: 0.77, blue: 0.94, alpha: 1).setFill()
    for y in [CGFloat(657), 597, 537] {
        NSBezierPath(roundedRect: NSRect(x: 409, y: y, width: 208, height: 18), xRadius: 9, yRadius: 9).fill()
    }

    NSColor(red: 0.12, green: 0.30, blue: 0.66, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 206, y: 230, width: 612, height: 252), xRadius: 68, yRadius: 68).fill()
    let lip = NSBezierPath()
    lip.move(to: NSPoint(x: 216, y: 448))
    lip.line(to: NSPoint(x: 361, y: 448))
    lip.curve(to: NSPoint(x: 422, y: 385), controlPoint1: NSPoint(x: 370, y: 405), controlPoint2: NSPoint(x: 391, y: 385))
    lip.line(to: NSPoint(x: 602, y: 385))
    lip.curve(to: NSPoint(x: 663, y: 448), controlPoint1: NSPoint(x: 633, y: 385), controlPoint2: NSPoint(x: 654, y: 405))
    lip.line(to: NSPoint(x: 808, y: 448))
    lip.line(to: NSPoint(x: 808, y: 313))
    lip.curve(to: NSPoint(x: 740, y: 244), controlPoint1: NSPoint(x: 808, y: 267), controlPoint2: NSPoint(x: 784, y: 244))
    lip.line(to: NSPoint(x: 284, y: 244))
    lip.curve(to: NSPoint(x: 216, y: 313), controlPoint1: NSPoint(x: 240, y: 244), controlPoint2: NSPoint(x: 216, y: 267))
    lip.close()
    NSColor.white.withAlphaComponent(0.95).setFill()
    lip.fill()
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: destination.appendingPathComponent("Contents.json"))
print("Generated Draglet app icon at \(destination.path)")
