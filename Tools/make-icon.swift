// Generates Resources/AppIcon.icns.
//
// The icon is drawn rather than shipped as binary art so it stays reviewable
// in a diff. Run it from the repo root:
//
//   swift Tools/make-icon.swift
//
// It writes Resources/AppIcon.iconset and then packs it into AppIcon.icns.

import AppKit
import Foundation

let canvasSize: CGFloat = 1024
let outputDir = URL(fileURLWithPath: "Resources")
let iconsetURL = outputDir.appendingPathComponent("AppIcon.iconset")

// macOS app icons sit in a squircle that does not reach the edges of the
// canvas. These proportions match the ones Apple uses in its own templates.
let inset: CGFloat = 100
let cornerRadius: CGFloat = 185

/// A tinted SF Symbol.
func symbol(_ name: String, side: CGFloat, color: NSColor) -> NSImage {
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
    let size = NSImage.SymbolConfiguration(pointSize: side, weight: .regular)
    let palette = NSImage.SymbolConfiguration(paletteColors: [color])
    return image.withSymbolConfiguration(size.applying(palette)) ?? image
}

/// The icon at a given pixel size.
func renderIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext

    // Clear to transparent so the squircle reads as a standalone shape.
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    let scale = size / canvasSize
    let body = CGRect(
        x: inset * scale,
        y: inset * scale,
        width: (canvasSize - inset * 2) * scale,
        height: (canvasSize - inset * 2) * scale
    )

    // Everything is drawn inside the squircle and clipped to it, so the moon
    // can bleed over the corner cleanly instead of floating outside the shape.
    context.saveGState()
    let squircle = NSBezierPath(
        roundedRect: body,
        xRadius: cornerRadius * scale,
        yRadius: cornerRadius * scale
    )
    context.addPath(squircle.cgPath)
    context.clip()

    // Night sky.
    let gradient = NSGradient(
        starting: NSColor(red: 0.30, green: 0.25, blue: 0.56, alpha: 1),
        ending: NSColor(red: 0.06, green: 0.05, blue: 0.15, alpha: 1)
    )!
    gradient.draw(in: body, angle: -90)

    // The cup, centred and slightly below the middle.
    let cupSide = body.width * 0.52
    let cupRect = NSRect(
        x: body.midX - cupSide / 2 - body.width * 0.04,
        y: body.midY - cupSide / 2 - body.height * 0.04,
        width: cupSide,
        height: cupSide
    )
    symbol("cup.and.saucer.fill", side: cupSide, color: .white)
        .draw(in: cupRect, from: .zero, operation: .sourceOver, fraction: 1)

    // A warm crescent moon over the top right corner. Drawn by hand because
    // the SF Symbol crescent does not read well at icon sizes.
    let moonRadius = body.width * 0.21
    let moonCenter = CGPoint(x: body.maxX - body.width * 0.13, y: body.maxY - body.width * 0.13)

    let outer = CGMutablePath()
    outer.addArc(
        center: moonCenter,
        radius: moonRadius,
        startAngle: 0,
        endAngle: 2 * .pi,
        clockwise: false
    )
    // A second circle, pushed up and to the right, carves the crescent out
    // of the first. Filling both paths with the even-odd rule subtracts it.
    let bite = CGMutablePath()
    bite.addArc(
        center: CGPoint(x: moonCenter.x + moonRadius * 0.42, y: moonCenter.y + moonRadius * 0.42),
        radius: moonRadius * 0.92,
        startAngle: 0,
        endAngle: 2 * .pi,
        clockwise: false
    )
    outer.addPath(bite)

    context.addPath(outer)
    context.setFillColor(NSColor(red: 1.0, green: 0.82, blue: 0.40, alpha: 1).cgColor)
    context.fillPath(using: .evenOdd)

    context.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

func write(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("could not encode \(url.lastPathComponent)\n".utf8))
        exit(1)
    }
    try! data.write(to: url)
}

try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

for variant in variants {
    let rep = renderIcon(size: variant.pixels)
    write(rep, to: iconsetURL.appendingPathComponent("\(variant.name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c", "icns",
    iconsetURL.path,
    "-o", outputDir.appendingPathComponent("AppIcon.icns").path
]
try! iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(1)
}

print("wrote \(outputDir.path)/AppIcon.icns")
