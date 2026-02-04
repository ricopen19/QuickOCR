import Foundation
import AppKit
import Vision

// MARK: - Error

enum OCRError: LocalizedError {
    case noTextFound
    case invalidImage
    case processingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "テキストを認識できませんでした。別の範囲を選択してください。"
        case .invalidImage:
            return "画像の変換に失敗しました。"
        case .processingFailed(let error):
            return "OCR処理に失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service

/// Vision Frameworkを使用したOCRサービス
final class OCRService {
    private let languages = ["ja", "en"]

    /// Vision モデルを事前にロードし、初回OCR時の遅延を排除する
    static func warmUp() {
        let pixels: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return }
        guard let cgImage = CGImage(
            width: 1, height: 1,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil,
            shouldInterpolate: false, intent: .perceptual
        ) else { return }

        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["ja", "en"]
        request.recognitionLevel = .accurate
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
    }

    /// 画像からテキストを認識する
    /// - throws: テキストが見つからない場合は `OCRError.noTextFound`、画像変換に失敗した場合は `OCRError.invalidImage`
    func recognizeText(in image: NSImage) throws -> OCRResult {
        let startTime = Date()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = languages
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let candidates = observations.compactMap { $0.topCandidates(1).first }
        let text = candidates.map { $0.string }.joined(separator: "\n")

        guard !text.isEmpty else {
            throw OCRError.noTextFound
        }

        let confidence = candidates.map { $0.confidence }.reduce(0, +) / Float(candidates.count)

        return OCRResult(
            text: text,
            confidence: confidence,
            recognizedLanguage: "auto",
            processingTime: Date().timeIntervalSince(startTime)
        )
    }
}
