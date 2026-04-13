#!/usr/bin/env swift
import Cocoa

func generateIcon(size: Int, filename: String) {
    let sz = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                isPlanar: false, colorSpaceName: .deviceRGB,
                                bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Background gradient (rose pink)
    let colors = [
        NSColor(red: 0.914, green: 0.118, blue: 0.549, alpha: 1.0).cgColor,
        NSColor(red: 0.761, green: 0.094, blue: 0.357, alpha: 1.0).cgColor,
        NSColor(red: 0.533, green: 0.055, blue: 0.310, alpha: 1.0).cgColor,
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1])!
    let rect = CGRect(x: 0, y: 0, width: sz, height: sz)
    let radius = sz * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    cg.addPath(path)
    cg.clip()
    cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: sz), end: CGPoint(x: sz, y: 0), options: [])

    // Subtle glow
    let glowColors = [NSColor(white: 1, alpha: 0.15).cgColor, NSColor(white: 1, alpha: 0).cgColor]
    let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors as CFArray, locations: [0, 1])!
    cg.drawRadialGradient(glowGrad, startCenter: CGPoint(x: sz*0.3, y: sz*0.7), startRadius: 0, endCenter: CGPoint(x: sz*0.3, y: sz*0.7), endRadius: sz*0.6, options: [])

    if size >= 32 {
        // Draw 5-petal flower
        let centerX = sz / 2
        let centerY = sz * 0.56
        let petalLength = sz * 0.18
        let petalWidth = sz * 0.12

        cg.saveGState()

        // Draw 5 white petals, each rotated 72 degrees
        for i in 0..<5 {
            let angle = CGFloat(i) * (2.0 * .pi / 5.0) - (.pi / 2.0)

            cg.saveGState()
            cg.translateBy(x: centerX, y: centerY)
            cg.rotate(by: angle)

            // Each petal is an oval (ellipse) centered offset from flower center
            let petalRect = CGRect(
                x: -petalWidth / 2,
                y: 0,
                width: petalWidth,
                height: petalLength
            )
            let petalPath = CGPath(ellipseIn: petalRect, transform: nil)

            // White petal with slight transparency
            cg.setFillColor(NSColor(white: 1.0, alpha: 0.92).cgColor)
            cg.addPath(petalPath)
            cg.fillPath()

            // Thin white border on petals
            cg.setStrokeColor(NSColor(white: 1.0, alpha: 0.5).cgColor)
            cg.setLineWidth(sz * 0.005)
            cg.addPath(petalPath)
            cg.strokePath()

            cg.restoreGState()
        }

        // Pink center circle
        let centerRadius = sz * 0.055
        let centerCircle = CGRect(
            x: centerX - centerRadius,
            y: centerY - centerRadius,
            width: centerRadius * 2,
            height: centerRadius * 2
        )
        let pinkCenterColors = [
            NSColor(red: 0.914, green: 0.118, blue: 0.549, alpha: 1.0).cgColor,
            NSColor(red: 0.761, green: 0.094, blue: 0.357, alpha: 1.0).cgColor,
        ]
        let pinkGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: pinkCenterColors as CFArray, locations: [0, 1])!
        cg.saveGState()
        cg.addEllipse(in: centerCircle)
        cg.clip()
        cg.drawRadialGradient(pinkGrad,
                              startCenter: CGPoint(x: centerX, y: centerY),
                              startRadius: 0,
                              endCenter: CGPoint(x: centerX, y: centerY),
                              endRadius: centerRadius,
                              options: [])
        cg.restoreGState()

        // White border around center
        cg.setStrokeColor(NSColor(white: 1.0, alpha: 0.7).cgColor)
        cg.setLineWidth(sz * 0.008)
        cg.addEllipse(in: centerCircle)
        cg.strokePath()

        cg.restoreGState()

        // "Miss M" text below flower
        let titleFont = NSFont(name: "Georgia-BoldItalic", size: sz * 0.13) ?? NSFont.boldSystemFont(ofSize: sz * 0.13)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: NSColor.white]
        let title = "Miss M"
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: NSPoint(x: (sz - titleSize.width) / 2, y: sz * 0.22), withAttributes: titleAttrs)

        if size >= 64 {
            // "ASSISTANT" subtitle
            let subFont = NSFont.systemFont(ofSize: sz * 0.055, weight: .medium)
            let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: NSColor(white: 1, alpha: 0.7)]
            let sub = "ASSISTANT"
            let subSize = sub.size(withAttributes: subAttrs)
            sub.draw(at: NSPoint(x: (sz - subSize.width) / 2, y: sz * 0.13), withAttributes: subAttrs)
        }
    } else {
        // Too small for detail, draw simple flower shape
        let centerX = sz / 2
        let centerY = sz / 2
        let petalLen = sz * 0.25
        let petalW = sz * 0.18

        cg.saveGState()
        for i in 0..<5 {
            let angle = CGFloat(i) * (2.0 * .pi / 5.0) - (.pi / 2.0)
            cg.saveGState()
            cg.translateBy(x: centerX, y: centerY)
            cg.rotate(by: angle)
            let petalRect = CGRect(x: -petalW / 2, y: 0, width: petalW, height: petalLen)
            cg.setFillColor(NSColor.white.cgColor)
            cg.fillEllipse(in: petalRect)
            cg.restoreGState()
        }
        // Center dot
        let r = sz * 0.1
        cg.setFillColor(NSColor(red: 0.914, green: 0.118, blue: 0.549, alpha: 1.0).cgColor)
        cg.fillEllipse(in: CGRect(x: centerX - r, y: centerY - r, width: r*2, height: r*2))
        cg.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: filename))
    print("Generated: \(filename) (\(size)x\(size))")
}

let base = "MissM/Assets.xcassets/AppIcon.appiconset/"

// macOS icon sizes: 1x point sizes and 2x retina
let sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes {
    generateIcon(size: s, filename: "\(base)icon_\(s)x\(s).png")
}
print("Done!")
