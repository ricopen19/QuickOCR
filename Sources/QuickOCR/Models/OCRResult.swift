import Foundation

struct OCRResult {
    let text: String
    let confidence: Float
    let recognizedLanguage: String
    let processingTime: TimeInterval
}
