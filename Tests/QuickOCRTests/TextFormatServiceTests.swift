import XCTest
@testable import QuickOCR

final class TextFormatServiceTests: XCTestCase {
    var service: TextFormatService!
    
    override func setUp() {
        super.setUp()
        service = TextFormatService()
    }
    
    // 正常系: 単一改行結合
    func testSingleNewline() {
        let input = "Hello\nWorld"
        let expected = "Hello World"
        XCTAssertEqual(service.format(input), expected)
    }
    
    // 正常系: 複数改行正規化
    func testMultipleNewlines() {
        let input = "Paragraph 1\n\nParagraph 2"
        let expected = "Paragraph 1\n\nParagraph 2"
        XCTAssertEqual(service.format(input), expected)
        
        // 3つ以上の改行も2つに
        let input3 = "Paragraph 1\n\n\nParagraph 2"
        XCTAssertEqual(service.format(input3), expected)
    }
    
    // 正常系: 混在
    func testMixed() {
        let input = "Line 1\nLine 2\n\nParagraph 2\nContinued"
        let expected = "Line 1 Line 2\n\nParagraph 2 Continued"
        XCTAssertEqual(service.format(input), expected)
    }
    
    // 異常系: 空文字列
    func testEmpty() {
        XCTAssertEqual(service.format(""), "")
    }
    
    // 異常系: 改行のみ
    func testNewlinesOnly() {
        XCTAssertEqual(service.format("\n"), "")
        XCTAssertEqual(service.format("\n\n"), "")
        // トリムされるので空文字になるはず
    }
    
    // 境界値: スペースのみの行を含む
    func testSpaceOnlyLine() {
        // "Hello\n   \nWorld" -> \n\n (段落区切り)
        let input = "Hello\n   \nWorld"
        let expected = "Hello\n\nWorld"
        XCTAssertEqual(service.format(input), expected)
    }
    
    // 境界値: 先頭末尾の空白
    func testTrimming() {
        let input = "  Hello\nWorld  "
        let expected = "Hello World"
        XCTAssertEqual(service.format(input), expected)
    }
    
    // 境界値: 日本語（仕様通りスペースが入ることを確認）
    func testJapanese() {
        let input = "あいう\nえお"
        let expected = "あいう えお"
        XCTAssertEqual(service.format(input), expected)
    }
    // 境界値: CRLF改行
    func testCRLF() {
        // \r\n が単一改行として扱われ、スペースに置換されることを期待
        // まず正規化で \r が消えるか、あるいは \r\n が改行として扱われるか。
        // TextFormatServiceの実装によっては \r が残る可能性があるため、このテストで挙動を確認・規定する。
        let input = "Line1\r\nLine2"
        let expected = "Line1 Line2"
        XCTAssertEqual(service.format(input), expected)
    }
}
