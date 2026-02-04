import AppKit

/// 全画面オーバーレイ上で矩形選択を行うビュー
final class SelectionOverlayView: NSView {
    private let screenshot: NSImage
    private var selectionStart: CGPoint?
    private var selectionRect: CGRect?

    /// 選択完了時に呼ばれるコールバック。引数はビュー座標系の矩形
    var onComplete: ((CGRect) -> Void)?
    /// キャンセル時に呼ばれるコールバック
    var onCancel: (() -> Void)?

    init(screenshot: NSImage, frame: CGRect) {
        self.screenshot = screenshot
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 座標原点を左上にする（CGImageと同じ座標系）
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: CGRect) {
        // ダーク半透明オーバーレイ付きスクリーンショット
        screenshot.draw(in: bounds)
        NSColor(white: 0, alpha: 0.5).set()
        NSBezierPath(rect: bounds).fill()

        // 選択範囲：オーバーレイを除いて元画像を表示
        guard let rect = selectionRect, rect.width > 0, rect.height > 0 else { return }
        
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        screenshot.draw(in: bounds)
        NSGraphicsContext.restoreGraphicsState()

        // 選択枠ボーダー（白・半透明・影なしでくっきり）
        let borderPath = NSBezierPath(rect: rect)
        borderPath.lineWidth = 1
        NSColor.white.set()
        borderPath.stroke()
        
        // 四隅のマーカー
        drawCornerMarkers(in: rect)
        
        // サイズ表示
        drawSizeLabel(for: rect)
    }
    
    private func drawCornerMarkers(in rect: CGRect) {
        let length: CGFloat = 8
        let thickness: CGFloat = 2
        
        let path = NSBezierPath()
        
        // 左上
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.line(to: CGPoint(x: rect.minX, y: rect.minY))
        path.line(to: CGPoint(x: rect.minX + length, y: rect.minY))
        
        // 右上
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        
        // 右下
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        
        // 左下
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        
        path.lineWidth = thickness
        NSColor.white.set()
        path.stroke()
    }
    
    private func drawSizeLabel(for rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]
        
        let size = (text as NSString).size(withAttributes: attrs)
        // 枠の上に表示（上が埋まっていたら下に）
        var point = CGPoint(x: rect.minX, y: rect.minY - size.height - 4)
        if point.y < 0 {
            point.y = rect.maxY + 4
        }
        
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    // MARK: - マウスイベント

    override func mouseDown(with event: NSEvent) {
        selectionStart = convert(event.locationInWindow, from: nil)
        selectionRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = selectionStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        let origin = CGPoint(x: min(start.x, current.x), y: min(start.y, current.y))
        let size = CGSize(width: abs(current.x - start.x), height: abs(current.y - start.y))
        selectionRect = CGRect(origin: origin, size: size)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let rect = selectionRect, rect.width > 1, rect.height > 1 {
            onComplete?(rect)
        } else {
            onCancel?()
        }
    }

    // MARK: - キャンセル

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }
}
