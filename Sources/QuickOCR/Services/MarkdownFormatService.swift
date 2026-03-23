import Foundation

/// OCR 結果を Markdown 記法に変換するサービス
final class MarkdownFormatService {

    // MARK: - 設定定数

    /// 見出しと判定するための高さ比率の閾値（中央値に対する倍率）
    private let heading1Threshold: CGFloat = 1.8
    private let heading2Threshold: CGFloat = 1.3

    /// テーブル検出: 同一行とみなす Y 座標の許容差（正規化座標）
    private let rowGroupingTolerance: CGFloat = 0.01

    /// テーブル検出: 列とみなす最小セル数
    private let minColumnsForTable = 2
    /// テーブル検出: テーブルとみなす最小行数
    private let minRowsForTable = 2

    // MARK: - Public

    /// OCRResult の行情報から Markdown テキストを生成する
    func format(_ lines: [OCRTextLine]) -> String {
        guard !lines.isEmpty else { return "" }

        // Vision 座標系は左下原点・Y が上向きなので、上から順に並べるには Y 降順でソート
        let sorted = lines.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        // テーブル検出を試みる
        let tableRanges = detectTableRanges(in: sorted)

        var result: [String] = []
        var tableLineIndices = Set<Int>()
        for range in tableRanges {
            for i in range { tableLineIndices.insert(i) }
        }

        // 見出し判定用の中央値高さを計算
        let medianHeight = computeMedianHeight(sorted)

        var i = 0
        while i < sorted.count {
            if tableLineIndices.contains(i) {
                // このインデックスが属するテーブル範囲を見つける
                if let range = tableRanges.first(where: { $0.contains(i) }), range.lowerBound == i {
                    let tableLines = Array(sorted[range])
                    let markdown = formatTable(tableLines)
                    result.append(markdown)
                    i = range.upperBound
                    continue
                }
                // テーブル範囲の途中（range.lowerBound != i）はスキップ（上で処理済み）
                i += 1
                continue
            }

            let line = sorted[i]
            let formatted = formatLine(line, medianHeight: medianHeight)
            result.append(formatted)
            i += 1
        }

        return result.joined(separator: "\n")
    }

    // MARK: - 行フォーマット

    private func formatLine(_ line: OCRTextLine, medianHeight: CGFloat) -> String {
        let text = line.text.trimmingCharacters(in: .whitespaces)

        // リスト検出
        if let listItem = detectListItem(text) {
            return listItem
        }

        // 見出し検出（高さベース）
        if medianHeight > 0 {
            let ratio = line.boundingBox.height / medianHeight
            if ratio >= heading1Threshold {
                return "# \(text)"
            } else if ratio >= heading2Threshold {
                return "## \(text)"
            }
        }

        return text
    }

    /// リストアイテムを検出して Markdown 記法に変換する
    private func detectListItem(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // 番号付きリスト: "1. ", "2) ", "１．" など
        let numberedPatterns = [
            try? Regex("^(\\d+)[.．)）]\\s*(.+)"),
            try? Regex("^([０-９]+)[.．)）]\\s*(.+)")
        ]
        for pattern in numberedPatterns.compactMap({ $0 }) {
            if let match = trimmed.firstMatch(of: pattern), match.output.count >= 3 {
                let num = String(trimmed[match.output[1].range!])
                let content = String(trimmed[match.output[2].range!])
                return "\(num). \(content)"
            }
        }

        // 箇条書き: "・", "•", "‣", "－", "―", "- " など
        let bulletPrefixes = ["・", "•", "‣", "－", "―", "▪", "▸", "►"]
        for prefix in bulletPrefixes {
            if trimmed.hasPrefix(prefix) {
                let content = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return "- \(content)"
            }
        }

        // "- " で始まる場合はそのまま
        if trimmed.hasPrefix("- ") {
            return trimmed
        }

        return nil
    }

    // MARK: - テーブル検出

    /// テーブルとして検出された行のインデックス範囲を返す
    private func detectTableRanges(in lines: [OCRTextLine]) -> [Range<Int>] {
        // Y 座標で行をグルーピング
        let rows = groupIntoRows(lines)

        // 複数セルを持つ行が連続する範囲を検出
        var ranges: [Range<Int>] = []
        var currentStart: Int? = nil
        var multiColRowCount = 0

        for (rowIndex, row) in rows.enumerated() {
            if row.cells.count >= minColumnsForTable {
                if currentStart == nil {
                    currentStart = row.startIndex
                }
                multiColRowCount += 1
            } else {
                if let start = currentStart, multiColRowCount >= minRowsForTable {
                    let endIndex = rows[rowIndex - 1].endIndex
                    ranges.append(start..<endIndex)
                }
                currentStart = nil
                multiColRowCount = 0
            }
        }

        // 末尾のテーブル
        if let start = currentStart, multiColRowCount >= minRowsForTable {
            let endIndex = rows.last!.endIndex
            ranges.append(start..<endIndex)
        }

        return ranges
    }

    private struct RowGroup {
        let cells: [OCRTextLine]
        /// lines 配列内の開始インデックス
        let startIndex: Int
        /// lines 配列内の終了インデックス（排他）
        let endIndex: Int
    }

    /// Y 座標が近い行をグルーピングする
    private func groupIntoRows(_ lines: [OCRTextLine]) -> [RowGroup] {
        guard !lines.isEmpty else { return [] }

        var rows: [RowGroup] = []
        var currentCells: [OCRTextLine] = [lines[0]]
        var currentY = lines[0].boundingBox.midY
        var startIndex = 0

        for i in 1..<lines.count {
            let line = lines[i]
            if abs(line.boundingBox.midY - currentY) <= rowGroupingTolerance {
                currentCells.append(line)
            } else {
                // X 座標でソートしてから追加
                let sorted = currentCells.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                rows.append(RowGroup(cells: sorted, startIndex: startIndex, endIndex: i))
                currentCells = [line]
                currentY = line.boundingBox.midY
                startIndex = i
            }
        }

        let sorted = currentCells.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        rows.append(RowGroup(cells: sorted, startIndex: startIndex, endIndex: lines.count))

        return rows
    }

    /// テーブル行群を Markdown テーブルに変換する
    private func formatTable(_ lines: [OCRTextLine]) -> String {
        let rows = groupIntoRows(lines)
        guard !rows.isEmpty else { return "" }

        // 最大列数を求める
        let maxCols = rows.map { $0.cells.count }.max() ?? 0
        guard maxCols >= minColumnsForTable else {
            return lines.map { $0.text }.joined(separator: "\n")
        }

        var tableRows: [[String]] = []
        for row in rows {
            var cells = row.cells.map { $0.text.trimmingCharacters(in: .whitespaces) }
            // 列数を揃える
            while cells.count < maxCols {
                cells.append("")
            }
            tableRows.append(cells)
        }

        // Markdown テーブルを生成
        var result: [String] = []

        // ヘッダー行
        let header = "| " + tableRows[0].joined(separator: " | ") + " |"
        result.append(header)

        // セパレータ
        let separator = "| " + tableRows[0].map { _ in "---" }.joined(separator: " | ") + " |"
        result.append(separator)

        // データ行
        for row in tableRows.dropFirst() {
            let line = "| " + row.joined(separator: " | ") + " |"
            result.append(line)
        }

        return result.joined(separator: "\n")
    }

    // MARK: - ユーティリティ

    private func computeMedianHeight(_ lines: [OCRTextLine]) -> CGFloat {
        let heights = lines.map { $0.boundingBox.height }.sorted()
        guard !heights.isEmpty else { return 0 }
        let mid = heights.count / 2
        if heights.count % 2 == 0 {
            return (heights[mid - 1] + heights[mid]) / 2.0
        } else {
            return heights[mid]
        }
    }
}
