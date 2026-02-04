import Foundation

final class TextFormatService {
    /// テキストをフォーマットする
    /// - Parameter text: 元のテキスト
    /// - Returns: フォーマット済みのテキスト
    ///
    /// 処理内容:
    /// 1. 先頭・末尾の空白を除去
    /// 2. 段落区切り（2つ以上の改行）を `\n\n` に正規化
    /// 3. 単一の改行をスペースに置換して結合
    func format(_ text: String) -> String {
        // 1. 先頭・末尾の空白を除去
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 改行コードの正規化 (\r\n -> \n, \r -> \n)
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        // 2. 段落区切りを正規化
        // \n(\\s*\n)+ : 改行の後に、(空白文字* + 改行) が1回以上続くパターン
        // 例: \n\n, \n(space)\n, \n\n\n 等をすべて \n\n に置換
        do {
            let paragraphRegex = try Regex("\n(\\s*\n)+")
            result = result.replacing(paragraphRegex, with: "\n\n")
        } catch {
            print("Regex compilation error: \(error)")
            // 正規表現でエラーが出た場合は最低限の処理として \n\n への置換のみ試みる（通常ここには来ない）
            result = result.replacingOccurrences(of: "\n\n", with: "\n\n")
        }
        
        // 3. 段落ごとに単一改行を処理
        // \n\n で分割することで、段落内の改行のみを対象に操作できる
        let paragraphs = result.components(separatedBy: "\n\n")
        let processedParagraphs = paragraphs.map { paragraph in
            // 段落内の単一改行をスペースに置換
            paragraph.replacingOccurrences(of: "\n", with: " ")
        }
        
        // 段落を再結合
        return processedParagraphs.joined(separator: "\n\n")
    }
}
