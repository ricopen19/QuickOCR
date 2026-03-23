#!/usr/bin/env swift
import Cocoa

/// QuickOCR App Icon (Design C: クリーン + フレーム + "OCR")
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size // alias

    // ── 背景: 白グラデーション + 角丸 ──
    let radius = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 1),
        CGColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
    ]
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: bgColors as CFArray,
                                  locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: s, y: 0),
                           options: [])

    // ── フレーム矩形（選択範囲） ──
    let frameX = s * 0.21
    let frameY = s * 0.38  // flipped later
    let frameW = s * 0.58
    let frameH = s * 0.42
    let frameRect = CGRect(x: frameX, y: frameY, width: frameW, height: frameH)
    let frameLineWidth = max(s * 0.025, 1.5)

    ctx.setStrokeColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1))
    ctx.setLineWidth(frameLineWidth)
    let framePath = CGPath(roundedRect: frameRect, cornerWidth: s * 0.02, cornerHeight: s * 0.02, transform: nil)
    ctx.addPath(framePath)
    ctx.strokePath()

    // ── 角括弧アクセント（青） ──
    let accentColor = CGColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1)
    ctx.setStrokeColor(accentColor)
    ctx.setLineWidth(frameLineWidth * 1.2)
    ctx.setLineCap(.round)

    let cornerLen = s * 0.08

    // 左上角
    let tlX = frameX - s * 0.04
    let tlY = frameRect.maxY + s * 0.04
    ctx.move(to: CGPoint(x: tlX, y: tlY - cornerLen))
    ctx.addLine(to: CGPoint(x: tlX, y: tlY))
    ctx.addLine(to: CGPoint(x: tlX + cornerLen, y: tlY))
    ctx.strokePath()

    // 右下角
    let brX = frameRect.maxX + s * 0.04
    let brY = frameY - s * 0.04
    ctx.move(to: CGPoint(x: brX, y: brY + cornerLen))
    ctx.addLine(to: CGPoint(x: brX, y: brY))
    ctx.addLine(to: CGPoint(x: brX - cornerLen, y: brY))
    ctx.strokePath()

    // ── テキスト行（フレーム内） ──
    let lineColor = CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.3)
    ctx.setStrokeColor(lineColor)
    let textLineWidth = max(s * 0.018, 1)
    ctx.setLineWidth(textLineWidth)
    ctx.setLineCap(.round)

    let lineX = frameX + s * 0.06
    let lineWidths: [CGFloat] = [0.42, 0.32, 0.38]
    let lineSpacing = s * 0.065
    let firstLineY = frameRect.maxY - s * 0.1

    for (i, w) in lineWidths.enumerated() {
        let y = firstLineY - CGFloat(i) * lineSpacing
        ctx.move(to: CGPoint(x: lineX, y: y))
        ctx.addLine(to: CGPoint(x: lineX + s * w, y: y))
        ctx.strokePath()
    }

    // ── "OCR" テキスト（下部） ──
    let fontSize = s * 0.19
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let textColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor
    ]
    let text = "OCR" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textX = (s - textSize.width) / 2
    let textY = s * 0.12
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Error: Failed to create PNG for \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// ── Main ──
let args = CommandLine.arguments
guard args.count > 1 else {
    print("Usage: generate_app_icon.swift <output_dir>")
    exit(1)
}
let outputDir = args[1]
let iconsetDir = "\(outputDir)/AppIcon.iconset"

let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for entry in sizes {
    let image = drawIcon(size: entry.size)
    let path = "\(iconsetDir)/\(entry.name).png"
    savePNG(image, to: path)
    print("Generated: \(entry.name).png (\(Int(entry.size))x\(Int(entry.size)))")
}

print("Iconset created at: \(iconsetDir)")
