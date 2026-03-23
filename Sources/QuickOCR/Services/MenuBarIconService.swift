import AppKit

/// メニューバー用のカスタムアイコンを生成するサービス
public enum MenuBarIconService {
    /// メニューバー用テンプレートアイコン（角括弧 + Aa）を生成する
    public static func createIcon() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let color = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // テンプレート化するので黒で描画
        ctx.setStrokeColor(color)
        ctx.setLineCap(.round)

        let lineWidth: CGFloat = 1.8
        ctx.setLineWidth(lineWidth)

        // ── 左上の角括弧 ──
        ctx.move(to: CGPoint(x: 1, y: 12))
        ctx.addLine(to: CGPoint(x: 1, y: 16))
        ctx.addLine(to: CGPoint(x: 6, y: 16))
        ctx.strokePath()

        // ── 右下の角括弧 ──
        ctx.move(to: CGPoint(x: 17, y: 6))
        ctx.addLine(to: CGPoint(x: 17, y: 2))
        ctx.addLine(to: CGPoint(x: 12, y: 2))
        ctx.strokePath()

        // ── "Aa" テキスト ──
        let font = NSFont.systemFont(ofSize: 9, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let text = "Aa" as NSString
        let textSize = text.size(withAttributes: attrs)
        let textX = (size - textSize.width) / 2
        let textY = (size - textSize.height) / 2 - 0.5
        text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
