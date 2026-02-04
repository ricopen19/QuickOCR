import Foundation
import AppKit

/// クリップボード操作を抽象化するプロトコル
protocol PasteboardProtocol {
    @discardableResult
    func clearContents() -> Int
    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardProtocol {}

/// システムクリップボードへのコピーを担当するサービス
final class ClipboardService {
    private let pasteboard: PasteboardProtocol

    init(pasteboard: PasteboardProtocol = NSPasteboard.general) {
        self.pasteboard = pasteboard
    }

    /// テキストをクリップボードにコピーする
    /// - throws: クリップボードへの書き込みに失敗した場合は `ClipboardError.writeFailed`
    func copy(_ text: String) throws {
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw ClipboardError.writeFailed
        }
    }
}

enum ClipboardError: LocalizedError {
    case writeFailed

    var errorDescription: String? {
        "クリップボードへのコピーに失敗しました。"
    }
}
