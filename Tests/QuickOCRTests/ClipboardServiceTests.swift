import XCTest
import AppKit

@testable import QuickOCR

final class ClipboardServiceTests: XCTestCase {
    private var service: ClipboardService!
    
    override func setUp() {
        super.setUp()
        service = ClipboardService()
    }

    override func tearDown() {
        NSPasteboard.general.clearContents()
        super.tearDown()
    }

    // MARK: - 正常系

    func test_英語テキストのコピー_クリップボードに正しく書き込まれる() throws {
        try service.copy("Hello World")

        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, "Hello World")
    }

    func test_日本語テキストのコピー_クリップボードに正しく書き込まれる() throws {
        try service.copy("こんにちは世界")

        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, "こんにちは世界")
    }

    func test_連続コピー_最後のテキストのみが残る() throws {
        try service.copy("最初のテキスト")
        try service.copy("最後のテキスト")

        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, "最後のテキスト")
    }

    // MARK: - 境界値

    func test_空文字列のコピー_クリップボードに空文字列が書き込まれる() throws {
        try service.copy("")

        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, "")
    }

    func test_改行を含むテキストのコピー_改行が保持される() throws {
        let text = "行1\n行2\n行3"
        try service.copy(text)

        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, text)
    }

    // MARK: - 異常系

    func test_書き込み失敗_エラーが発生する() {
        let mock = MockPasteboard()
        mock.shouldFail = true
        let service = ClipboardService(pasteboard: mock)

        XCTAssertThrowsError(try service.copy("fail")) { error in
            XCTAssertEqual(error as? ClipboardError, .writeFailed)
        }
    }
}

// MARK: - Mocks

private class MockPasteboard: PasteboardProtocol {
    var shouldFail = false
    var contents: String?

    func clearContents() -> Int {
        contents = nil
        return 0
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        if shouldFail { return false }
        contents = string
        return true
    }
}
