import Foundation

/// キーボード修飾キーの種類
enum ModifierKey: String, Codable, CaseIterable, Hashable {
    case command
    case shift
    case option
    case control
}

/// キーバインド定義（CGEventTap で扱うキーコード + 修飾キーの組み合わせ）
struct KeyBinding: Codable, Equatable {
    /// CGEventTap のキーコード（例: 31 = "O" キー）
    let keyCode: Int
    /// 修飾キーの組み合わせ
    let modifiers: Set<ModifierKey>

    /// デフォルト: Cmd+Shift+O
    static let defaultOCR = KeyBinding(keyCode: 31, modifiers: [.command, .shift])
    /// デフォルト: Cmd+Shift+M (keyCode 46 = "M")
    static let defaultMarkdownOCR = KeyBinding(keyCode: 46, modifiers: [.command, .shift])
}

/// アプリ設定モデル
struct AppSettings: Codable {
    /// グローバルショートカットキー
    var shortcutKey: KeyBinding = .defaultOCR
    /// ログイン時に自動起動する
    var launchAtLogin: Bool = false
    /// OCR完了時の音声フィードバック
    var enableSoundFeedback: Bool = false
    /// テキストフォーマット処理（改行正規化）
    var enableTextFormatting: Bool = true
    /// Markdown OCR 用ショートカットキー
    var shortcutKeyMarkdown: KeyBinding = .defaultMarkdownOCR
}
