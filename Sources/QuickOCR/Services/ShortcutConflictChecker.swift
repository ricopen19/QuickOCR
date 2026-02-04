import Foundation

/// 設定されたキーバインドが既知のシステムショートカットと衝突するか確認するユーティリティ
final class ShortcutConflictChecker {
    /// 衝突する場合の警告メッセージを返す。衝突なしの場合は nil
    static func conflict(for binding: KeyBinding) -> String? {
        return knownShortcuts.first(where: { $0.binding == binding })?.message
    }

    private struct KnownShortcut {
        let binding: KeyBinding
        let message: String
    }

    /// 既知のシステム・アプリ共通ショートカット
    /// キーコードは macOS US QWERTY レイアウトの物理キーコード基準
    private static let knownShortcuts: [KnownShortcut] = [
        // 編集系
        KnownShortcut(binding: KeyBinding(keyCode: 0, modifiers: [.command]), message: "Cmd+A（全選択）と衝突します"),
        KnownShortcut(binding: KeyBinding(keyCode: 8, modifiers: [.command]), message: "Cmd+C（コピー）と衝突します"),
        KnownShortcut(binding: KeyBinding(keyCode: 9, modifiers: [.command]), message: "Cmd+V（貼り付け）と衝突します"),
        KnownShortcut(binding: KeyBinding(keyCode: 7, modifiers: [.command]), message: "Cmd+X（切り取り）と衝突します"),
        KnownShortcut(binding: KeyBinding(keyCode: 6, modifiers: [.command]), message: "Cmd+Z（アンドゥ）と衝突します"),
        KnownShortcut(
            binding: KeyBinding(keyCode: 6, modifiers: [.command, .shift]),
            message: "Cmd+Shift+Z（リドゥ）と衝突します"
        ),
        // ファイル系
        KnownShortcut(binding: KeyBinding(keyCode: 1, modifiers: [.command]), message: "Cmd+S（保存）と衝突します"),
        KnownShortcut(binding: KeyBinding(keyCode: 13, modifiers: [.command]), message: "Cmd+W（閉じる）と衝突します"),
        KnownShortcut(binding: KeyBinding(keyCode: 15, modifiers: [.command]), message: "Cmd+R（リロード）と衝突します"),
        // アプリ系
        KnownShortcut(binding: KeyBinding(keyCode: 12, modifiers: [.command]), message: "Cmd+Q（終了）と衝突します"),
        KnownShortcut(
            binding: KeyBinding(keyCode: 4, modifiers: [.command]),
            message: "Cmd+H（非表示にする）と衝突します"
        )
    ]
}
