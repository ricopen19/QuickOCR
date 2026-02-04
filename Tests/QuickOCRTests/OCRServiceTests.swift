import XCTest
import AppKit

@testable import QuickOCR

final class OCRServiceTests: XCTestCase {
    private let service = OCRService()

    // MARK: - テスト用画像生成

    /// 白地にテキストを描画した画像を生成する
    private func createTestImage(text: String, size: CGSize = CGSize(width: 600, height: 100)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.set()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28),
            .foregroundColor: NSColor.black
        ]
        (text as NSString).draw(at: CGPoint(x: 20, y: size.height / 2 - 14), withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    /// テキストが含まれない白地画像を生成する
    private func createBlankImage(size: CGSize = CGSize(width: 400, height: 100)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.set()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - 正常系

    func test_英語テキストのOCR_テキストが正しく抽出される() throws {
        let image = createTestImage(text: "Hello World")

        let result = try service.recognizeText(in: image)

        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.confidence > 0)
        XCTAssertTrue(result.processingTime > 0)
    }

    func test_英語テキストのOCR_抽出テキストに期待される文字列が含まれる() throws {
        let image = createTestImage(text: "Hello World")

        let result = try service.recognizeText(in: image)

        XCTAssertTrue(
            result.text.contains("Hello"),
            "抽出テキストに 'Hello' が含まれることが期待される。実際: '\(result.text)'"
        )
    }

    func test_日本語テキストのOCR_テキストが正しく抽出される() throws {
        let image = createTestImage(text: "こんにちは世界", size: CGSize(width: 600, height: 120))

        let result = try service.recognizeText(in: image)

        XCTAssertFalse(result.text.isEmpty, "日本語テキストが抽出されることが期待される。実際: 空文字列")
        XCTAssertTrue(result.confidence > 0)
    }

    // MARK: - 異常系

    func test_テキスト無し画像のOCR_noTextFoundエラーが発生する() {
        let image = createBlankImage()

        XCTAssertThrowsError(try service.recognizeText(in: image)) { error in
            guard let ocrError = error as? OCRError else {
                XCTFail("OCRError が期待される。実際: \(error)")
                return
            }
            if case .noTextFound = ocrError { } else {
                XCTFail("OCRError.noTextFound が期待される。実際: \(ocrError)")
            }
        }
    }

    func test_ゼロサイズ画像のOCR_エラーが発生する() {
        let image = NSImage(size: .zero)

        XCTAssertThrowsError(try service.recognizeText(in: image)) { error in
            guard error is OCRError else {
                XCTFail("OCRError が期待される。実際: \(error)")
                return
            }
        }
    }

    // MARK: - パフォーマンス

    func test_OCR処理時間が1秒以内に完了する() throws {
        let image = createTestImage(text: "Performance test")

        let result = try service.recognizeText(in: image)

        XCTAssertLessThan(result.processingTime, 1.0, "処理時間が1秒以内であることが期待される")
    }
    func test_warmUp_実行後の初回OCR_処理時間が短縮される() throws {
        OCRService.warmUp()

        let image = createTestImage(text: "Warm Up Test")
        let result = try service.recognizeText(in: image)

        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.processingTime < 1.0)
    }
}
