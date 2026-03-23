import XCTest
@testable import QuickOCR

final class MarkdownFormatServiceTests: XCTestCase {
    private let service = MarkdownFormatService()

    // MARK: - 基本

    func testEmptyLines() {
        XCTAssertEqual(service.format([]), "")
    }

    func testSingleLine() {
        let lines = [
            OCRTextLine(text: "Hello World", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.5, width: 1, height: 0.03))
        ]
        XCTAssertEqual(service.format(lines), "Hello World")
    }

    func testMultipleLines() {
        let lines = [
            OCRTextLine(text: "First", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.03)),
            OCRTextLine(text: "Second", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.8, width: 1, height: 0.03)),
            OCRTextLine(text: "Third", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.03))
        ]
        XCTAssertEqual(service.format(lines), "First\nSecond\nThird")
    }

    // MARK: - 見出し検出

    func testHeading1Detection() {
        let lines = [
            // 高さ 0.06 = 中央値 0.03 の 2.0 倍 → heading1
            OCRTextLine(text: "Big Title", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.06)),
            OCRTextLine(text: "Normal text", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.8, width: 1, height: 0.03)),
            OCRTextLine(text: "More text", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.03))
        ]
        let result = service.format(lines)
        XCTAssertTrue(result.hasPrefix("# Big Title"))
    }

    func testHeading2Detection() {
        let lines = [
            // 高さ 0.045 = 中央値 0.03 の 1.5 倍 → heading2
            OCRTextLine(text: "Subtitle", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.045)),
            OCRTextLine(text: "Normal text", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.8, width: 1, height: 0.03)),
            OCRTextLine(text: "More text", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.03))
        ]
        let result = service.format(lines)
        XCTAssertTrue(result.hasPrefix("## Subtitle"))
    }

    // MARK: - リスト検出

    func testBulletListDetection() {
        let lines = [
            OCRTextLine(text: "・項目1", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.03)),
            OCRTextLine(text: "•項目2", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.8, width: 1, height: 0.03)),
            OCRTextLine(text: "▸項目3", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.03))
        ]
        let result = service.format(lines)
        XCTAssertEqual(result, "- 項目1\n- 項目2\n- 項目3")
    }

    func testNumberedListDetection() {
        let lines = [
            OCRTextLine(text: "1. First item", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.03)),
            OCRTextLine(text: "2. Second item", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.8, width: 1, height: 0.03))
        ]
        let result = service.format(lines)
        XCTAssertEqual(result, "1. First item\n2. Second item")
    }

    func testDashListPassthrough() {
        let lines = [
            OCRTextLine(text: "- already markdown", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.03))
        ]
        XCTAssertEqual(service.format(lines), "- already markdown")
    }

    // MARK: - テーブル検出

    func testTableDetection() {
        // 2行×3列のテーブル（同じ Y 座標に複数セルが並ぶ）
        let y1: CGFloat = 0.9
        let y2: CGFloat = 0.8
        let lines = [
            OCRTextLine(text: "Name", confidence: 0.9, boundingBox: CGRect(x: 0.0, y: y1, width: 0.3, height: 0.03)),
            OCRTextLine(text: "Age", confidence: 0.9, boundingBox: CGRect(x: 0.35, y: y1, width: 0.3, height: 0.03)),
            OCRTextLine(text: "City", confidence: 0.9, boundingBox: CGRect(x: 0.7, y: y1, width: 0.3, height: 0.03)),
            OCRTextLine(text: "Alice", confidence: 0.9, boundingBox: CGRect(x: 0.0, y: y2, width: 0.3, height: 0.03)),
            OCRTextLine(text: "30", confidence: 0.9, boundingBox: CGRect(x: 0.35, y: y2, width: 0.3, height: 0.03)),
            OCRTextLine(text: "Tokyo", confidence: 0.9, boundingBox: CGRect(x: 0.7, y: y2, width: 0.3, height: 0.03))
        ]
        let result = service.format(lines)
        XCTAssertTrue(result.contains("| Name | Age | City |"))
        XCTAssertTrue(result.contains("| --- | --- | --- |"))
        XCTAssertTrue(result.contains("| Alice | 30 | Tokyo |"))
    }

    func testSingleRowNotTable() {
        // 1行だけでは テーブルにならない
        let lines = [
            OCRTextLine(text: "Col1", confidence: 0.9, boundingBox: CGRect(x: 0.0, y: 0.9, width: 0.3, height: 0.03)),
            OCRTextLine(text: "Col2", confidence: 0.9, boundingBox: CGRect(x: 0.5, y: 0.9, width: 0.3, height: 0.03))
        ]
        let result = service.format(lines)
        // テーブルにならないので通常テキスト
        XCTAssertFalse(result.contains("|"))
    }

    // MARK: - 混在

    func testHeadingWithList() {
        let lines = [
            OCRTextLine(text: "目次", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.06)),
            OCRTextLine(text: "・はじめに", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.03)),
            OCRTextLine(text: "・おわりに", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.6, width: 1, height: 0.03))
        ]
        let result = service.format(lines)
        XCTAssertTrue(result.hasPrefix("# 目次"))
        XCTAssertTrue(result.contains("- はじめに"))
        XCTAssertTrue(result.contains("- おわりに"))
    }

    // MARK: - ソート順

    func testLinesAreSortedTopToBottom() {
        // Y が大きい方が上（Vision 座標系）→ 出力は Y 降順
        let lines = [
            OCRTextLine(text: "Bottom", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.1, width: 1, height: 0.03)),
            OCRTextLine(text: "Top", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0.9, width: 1, height: 0.03))
        ]
        let result = service.format(lines)
        XCTAssertEqual(result, "Top\nBottom")
    }
}
