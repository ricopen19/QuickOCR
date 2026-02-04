import Foundation
import ScreenCaptureKit

enum CaptureError: LocalizedError {
    case captureFailed
    case unsupportedOS

    var errorDescription: String? {
        switch self {
        case .captureFailed: "画面キャプチャに失敗しました"
        case .unsupportedOS: "画面キャプチャはmacOS 15.2以降が必要です"
        }
    }
}

final class ScreenCaptureService {
    /// 指定された画面領域のスクリーンキャプチャを実行する
    static func captureImage(in rect: CGRect) async throws -> CGImage {
        guard #available(macOS 15.2, *) else {
            throw CaptureError.unsupportedOS
        }
        return try await captureImageAvailable(in: rect)
    }

    @available(macOS 15.2, *)
    private static func captureImageAvailable(in rect: CGRect) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? CaptureError.captureFailed)
                }
            }
        }
    }
}
