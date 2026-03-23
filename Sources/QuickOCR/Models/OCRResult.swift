import Foundation

/// OCR で認識された1行分のテキストと位置情報
struct OCRTextLine {
    /// 認識されたテキスト
    let text: String
    /// 認識の信頼度 (0.0–1.0)
    let confidence: Float
    /// 画像内での正規化バウンディングボックス (Vision 座標系: 左下原点, 0.0–1.0)
    let boundingBox: CGRect
}

struct OCRResult {
    let text: String
    let confidence: Float
    let recognizedLanguage: String
    let processingTime: TimeInterval
    /// 各行の詳細情報（Markdown 変換用）
    let lines: [OCRTextLine]
}
